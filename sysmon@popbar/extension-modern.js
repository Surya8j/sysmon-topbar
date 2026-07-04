/* SysMon TopBar - Lightweight system monitor for GNOME Shell top bar
 * htop-style terminal aesthetic
 * Views: CPU (per-core bar columns), RAM (htop bracket bars)
 * Click to cycle between views.
 */

'use strict';

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import Cairo from 'gi://cairo';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

// ─── Config ──────────────────────────────────────────────────────────────────
const CPU_POLL_MS = 2000;
const RAM_POLL_MS = 2000;

// htop terminal palette
const C = {
    d_fg:    [0.75, 0.75, 0.75, 1.0],
    d_dim:   [0.35, 0.35, 0.35, 0.6],
    d_green: [0.2, 0.8, 0.2, 1.0],
    d_cyan:  [0.3, 0.75, 0.85, 1.0],
    d_yellow:[0.85, 0.8, 0.2, 1.0],
    d_red:   [0.9, 0.2, 0.2, 1.0],
    l_fg:    [0.2, 0.2, 0.2, 1.0],
    l_dim:   [0.55, 0.55, 0.55, 0.6],
    l_green: [0.1, 0.6, 0.1, 1.0],
    l_cyan:  [0.15, 0.55, 0.65, 1.0],
    l_yellow:[0.7, 0.65, 0.05, 1.0],
    l_red:   [0.8, 0.15, 0.15, 1.0],
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

function readFile(path) {
    try {
        let [ok, contents] = GLib.file_get_contents(path);
        if (ok) {
            if (contents instanceof Uint8Array)
                return new TextDecoder().decode(contents);
            return contents.toString();
        }
    } catch (e) {}
    return '';
}

function isDarkTheme() {
    try {
        let settings = new Gio.Settings({ schema: 'org.gnome.desktop.interface' });
        let theme = settings.get_string('gtk-theme').toLowerCase();
        return theme.includes('dark');
    } catch (e) {
        return true;
    }
}

function formatMem(kb) {
    let gb = kb / (1024 * 1024);
    if (gb >= 1) return gb.toFixed(1) + 'G';
    return (kb / 1024).toFixed(0) + 'M';
}

function tc(dark, name) {
    return C[(dark ? 'd_' : 'l_') + name];
}

// ─── CPU Reader ──────────────────────────────────────────────────────────────

class CpuReader {
    constructor() { this._prev = null; }

    read() {
        let text = readFile('/proc/stat');
        let lines = text.split('\n');
        let cores = [];
        for (let line of lines) {
            if (line.startsWith('cpu') && !line.startsWith('cpu ')) {
                let parts = line.trim().split(/\s+/);
                let vals = parts.slice(1).map(Number);
                let idle = vals[3] + (vals[4] || 0);
                let total = vals.reduce((a, b) => a + b, 0);
                cores.push({ idle, total });
            }
        }
        let percents = [];
        if (this._prev && this._prev.length === cores.length) {
            for (let i = 0; i < cores.length; i++) {
                let dTotal = cores[i].total - this._prev[i].total;
                let dIdle = cores[i].idle - this._prev[i].idle;
                let usage = dTotal > 0 ? ((dTotal - dIdle) / dTotal) * 100 : 0;
                percents.push(Math.max(0, Math.min(100, usage)));
            }
        } else {
            percents = cores.map(() => 0);
        }
        this._prev = cores;
        return percents;
    }
}

// ─── RAM Reader ──────────────────────────────────────────────────────────────

class RamReader {
    read() {
        let text = readFile('/proc/meminfo');
        let get = (key) => {
            let m = text.match(new RegExp(key + ':\\s+(\\d+)'));
            return m ? parseInt(m[1]) : 0;
        };
        let memTotal = get('MemTotal');
        let memAvail = get('MemAvailable');
        let swapTotal = get('SwapTotal');
        let swapFree = get('SwapFree');
        return {
            memTotal,
            memUsed: memTotal - memAvail,
            swapTotal,
            swapUsed: swapTotal - swapFree,
        };
    }
}

// ─── Indicator ───────────────────────────────────────────────────────────────

const SysMonIndicator = GObject.registerClass(
class SysMonIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'SysMon TopBar', false);

        this._view = 0; // 0=CPU, 1=RAM
        this._dark = isDarkTheme();

        this._themeSettings = new Gio.Settings({ schema: 'org.gnome.desktop.interface' });
        this._themeChangedId = this._themeSettings.connect('changed::gtk-theme', () => {
            this._dark = isDarkTheme();
            this._canvas.queue_repaint();
        });

        this._cpuReader = new CpuReader();
        this._ramReader = new RamReader();

        // Get actual core count directly for reliable init sizing
        let statText = readFile('/proc/stat');
        let coreCount = 0;
        let statLines = statText.split('\n');
        for (let line of statLines) {
            if (line.startsWith('cpu') && !line.startsWith('cpu ')) coreCount++;
        }
        this._coreCount = coreCount || 8;

        this._cpuPercents = [];
        this._ramData = this._ramReader.read();

        // Prime CPU reader (needs two reads for delta)
        this._cpuReader.read();

        this._canvas = new St.DrawingArea({
            reactive: true,
            style_class: 'sysmon-canvas',
        });
        this._canvas.connect('repaint', (area) => this._draw(area));
        this.add_child(this._canvas);

        this._updateSize();

        // After a short delay, do the first real CPU read and resize
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
            this._cpuPercents = this._cpuReader.read();
            this._updateSize();
            this._canvas.queue_repaint();
            return GLib.SOURCE_REMOVE;
        });

        // Click to cycle views
        this.connect('button-press-event', () => {
            this._hideTooltip();
            this._view = (this._view + 1) % 2;
            // Force fresh data read for the new view
            if (this._view === 0) {
                this._cpuPercents = this._cpuReader.read();
            } else {
                this._ramData = this._ramReader.read();
            }
            this._updateSize();
            // Queue repaint after a tiny delay to let size change settle
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
                this._canvas.queue_repaint();
                // Re-show tooltip if still hovering, now with new view's data
                if (this.get_hover()) {
                    this._showTooltip();
                }
                return GLib.SOURCE_REMOVE;
            });
            return Clutter.EVENT_STOP;
        });

        // Tooltip state
        this._tooltip = null;
        this._tooltipAutoHideId = null;
        this._tooltipRefreshId = null;
        this.set_track_hover(true);
        this.connect('notify::hover', () => {
            if (this.get_hover()) this._showTooltip();
            else this._hideTooltip();
        });

        // Timers
        this._cpuTimerId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, CPU_POLL_MS, () => {
            let oldLen = this._cpuPercents.length;
            this._cpuPercents = this._cpuReader.read();
            if (this._view === 0) {
                // Update canvas size if core count changed (e.g. first real read)
                if (this._cpuPercents.length !== oldLen) this._updateSize();
                this._canvas.queue_repaint();
            }
            return GLib.SOURCE_CONTINUE;
        });

        this._ramTimerId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, RAM_POLL_MS, () => {
            this._ramData = this._ramReader.read();
            if (this._view === 1) this._canvas.queue_repaint();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _updateSize() {
        let w, h;
        let numCores = this._cpuPercents.length || this._coreCount || 8;
        switch (this._view) {
            case 0: w = numCores * 4 + 6; h = 24; break;
            case 1: w = 150; h = 22; break;
        }
        this._canvas.set_size(w, h);
    }

    _draw(area) {
        let cr = area.get_context();
        let [w, h] = area.get_surface_size();
        switch (this._view) {
            case 0: this._drawCPU(cr, w, h); break;
            case 1: this._drawRAM(cr, w, h); break;
        }
        cr.$dispose();
    }

    // ── CPU: vertical bar columns with htop color gradient ───────────────────
    // 0-30% green | 30-60% cyan | 60-85% yellow | 85-100% red
    _drawCPU(cr, w, h) {
        let percents = this._cpuPercents;
        if (!percents.length) return;
        let dark = this._dark;

        let barW = 2.5;
        let gap = 1.5;
        let totalW = percents.length * (barW + gap) - gap;
        let startX = Math.floor((w - totalW) / 2);
        let topPad = 2;
        let botPad = 2;
        let barMaxH = h - topPad - botPad;

        // Dim track per core
        cr.setSourceRGBA(...tc(dark, 'dim'));
        for (let c = 0; c < percents.length; c++) {
            let x = startX + c * (barW + gap);
            cr.rectangle(x, topPad, barW, barMaxH);
        }
        cr.fill();

        // Filled bars with color segments
        let segments = [
            { thresh: 30,  name: 'green'  },
            { thresh: 60,  name: 'cyan'   },
            { thresh: 85,  name: 'yellow' },
            { thresh: 100, name: 'red'    },
        ];

        for (let c = 0; c < percents.length; c++) {
            let pct = percents[c];
            if (pct <= 0) continue;

            let x = startX + c * (barW + gap);
            let drawnFrom = 0;

            for (let seg of segments) {
                if (pct <= drawnFrom) break;
                let segEnd = Math.min(pct, seg.thresh);
                let segH = ((segEnd - drawnFrom) / 100) * barMaxH;
                let segY = topPad + barMaxH - (segEnd / 100) * barMaxH;

                cr.setSourceRGBA(...tc(dark, seg.name));
                cr.rectangle(x, segY, barW, segH);
                cr.fill();

                drawnFrom = segEnd;
            }
        }
    }

    // ── RAM: htop bracket bars with vertical pipe fills ────────────────────
    // Mem[|||||||||       5.2G/32G]
    // Swp[|||             1.0G/10G]
    _drawRAM(cr, w, h) {
        let d = this._ramData;
        let dark = this._dark;

        cr.selectFontFace('monospace', Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.setFontSize(8);

        let labelW = 22;
        let barX = labelW + 2;
        let barW = 50;
        let barH = 8;
        let valX = barX + barW + 3;
        let lineGap = 11;
        let y1 = Math.floor(h / 2) - Math.floor(lineGap / 2) + 1;
        let y2 = y1 + lineGap;

        let pipeW = 1.5;   // width of each vertical pipe
        let pipeGap = 1.0; // gap between pipes
        let pipeStep = pipeW + pipeGap;
        let maxPipes = Math.floor(barW / pipeStep);

        // ─ Mem ─
        cr.setSourceRGBA(...tc(dark, 'fg'));
        cr.moveTo(2, y1 + 3);
        cr.showText('Mem');

        // Brackets
        cr.setSourceRGBA(...tc(dark, 'dim'));
        cr.moveTo(barX - 5, y1 + 3);
        cr.showText('[');
        cr.moveTo(barX + barW + 1, y1 + 3);
        cr.showText(']');

        // Vertical pipe fills for RAM
        let ramFrac = d.memTotal > 0 ? d.memUsed / d.memTotal : 0;
        let ramPipes = Math.round(maxPipes * ramFrac);
        cr.setSourceRGBA(...tc(dark, 'green'));
        for (let i = 0; i < ramPipes; i++) {
            let px = barX + i * pipeStep;
            cr.rectangle(px, y1 - barH / 2, pipeW, barH);
        }
        cr.fill();

        // Dim unfilled pipes
        cr.setSourceRGBA(...tc(dark, 'dim'));
        for (let i = ramPipes; i < maxPipes; i++) {
            let px = barX + i * pipeStep;
            cr.rectangle(px, y1 - barH / 2, pipeW, barH);
        }
        cr.fill();

        // Value
        cr.setSourceRGBA(...tc(dark, 'fg'));
        cr.moveTo(valX + 4, y1 + 3);
        cr.showText(formatMem(d.memUsed) + '/' + formatMem(d.memTotal));

        // ─ Swp ─
        cr.setSourceRGBA(...tc(dark, 'fg'));
        cr.moveTo(2, y2 + 3);
        cr.showText('Swp');

        // Brackets
        cr.setSourceRGBA(...tc(dark, 'dim'));
        cr.moveTo(barX - 5, y2 + 3);
        cr.showText('[');
        cr.moveTo(barX + barW + 1, y2 + 3);
        cr.showText(']');

        // Vertical pipe fills for Swap
        let swapFrac = d.swapTotal > 0 ? d.swapUsed / d.swapTotal : 0;
        let swapPipes = Math.round(maxPipes * swapFrac);
        cr.setSourceRGBA(...tc(dark, 'red'));
        for (let i = 0; i < swapPipes; i++) {
            let px = barX + i * pipeStep;
            cr.rectangle(px, y2 - barH / 2, pipeW, barH);
        }
        cr.fill();

        // Dim unfilled pipes
        cr.setSourceRGBA(...tc(dark, 'dim'));
        for (let i = swapPipes; i < maxPipes; i++) {
            let px = barX + i * pipeStep;
            cr.rectangle(px, y2 - barH / 2, pipeW, barH);
        }
        cr.fill();

        // Value
        cr.setSourceRGBA(...tc(dark, 'fg'));
        cr.moveTo(valX + 4, y2 + 3);
        cr.showText(formatMem(d.swapUsed) + '/' + formatMem(d.swapTotal));
    }

    // ── Tooltip ──────────────────────────────────────────────────────────────
    // Builds tooltip text based on CURRENT view and CURRENT data

    _getTooltipText() {
        switch (this._view) {
            case 0: {
                let p = this._cpuPercents;
                if (!p.length) return '';
                let lines = [];
                let half = Math.ceil(p.length / 2);
                for (let i = 0; i < half; i++) {
                    let left = i.toString().padStart(2) + ':' +
                               p[i].toFixed(1).padStart(5) + '%';
                    let right = '';
                    if (i + half < p.length) {
                        right = '  ' + (i + half).toString().padStart(2) + ':' +
                                p[i + half].toFixed(1).padStart(5) + '%';
                    }
                    lines.push(left + right);
                }
                return lines.join('\n');
            }
            case 1: {
                let d = this._ramData;
                let rp = d.memTotal > 0 ? ((d.memUsed / d.memTotal) * 100).toFixed(1) : '0.0';
                let sp = d.swapTotal > 0 ? ((d.swapUsed / d.swapTotal) * 100).toFixed(1) : '0.0';
                return 'Mem ' + formatMem(d.memUsed) + '/' + formatMem(d.memTotal) + ' ' + rp + '%' +
                       '\nSwp ' + formatMem(d.swapUsed) + '/' + formatMem(d.swapTotal) + ' ' + sp + '%';
            }
        }
        return '';
    }

    _showTooltip() {
        this._hideTooltip();

        let text = this._getTooltipText();
        if (!text) return;

        this._tooltip = new St.Label({
            text: text,
            style_class: 'sysmon-tooltip',
            style: 'background-color: rgba(5,5,5,0.94); color: #a0a0a0; ' +
                   'padding: 4px 8px; border-radius: 1px; font-size: 10px; ' +
                   'font-family: monospace; letter-spacing: 0.3px; ' +
                   'border: 1px solid rgba(80,80,80,0.4);',
        });

        Main.uiGroup.add_child(this._tooltip);
        let [x, y] = this.get_transformed_position();
        this._tooltip.set_position(Math.max(0, x), y + this.get_height() + 4);

        // Live-update tooltip text every second while hovering
        this._tooltipRefreshId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
            if (this._tooltip) {
                let newText = this._getTooltipText();
                if (newText) this._tooltip.set_text(newText);
                return GLib.SOURCE_CONTINUE;
            }
            this._tooltipRefreshId = null;
            return GLib.SOURCE_REMOVE;
        });

        // Auto-hide fallback after 6 seconds
        this._tooltipAutoHideId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 6000, () => {
            this._hideTooltip();
            return GLib.SOURCE_REMOVE;
        });
    }

    _hideTooltip() {
        if (this._tooltipAutoHideId) {
            GLib.source_remove(this._tooltipAutoHideId);
            this._tooltipAutoHideId = null;
        }
        if (this._tooltipRefreshId) {
            GLib.source_remove(this._tooltipRefreshId);
            this._tooltipRefreshId = null;
        }
        if (this._tooltip) {
            Main.uiGroup.remove_child(this._tooltip);
            this._tooltip.destroy();
            this._tooltip = null;
        }
    }

    destroy() {
        if (this._cpuTimerId) { GLib.source_remove(this._cpuTimerId); this._cpuTimerId = null; }
        if (this._ramTimerId) { GLib.source_remove(this._ramTimerId); this._ramTimerId = null; }
        if (this._themeChangedId) {
            this._themeSettings.disconnect(this._themeChangedId);
            this._themeChangedId = null;
        }
        this._hideTooltip();
        super.destroy();
    }
});

export default class SysMonExtension extends Extension {
    enable() {
        this._indicator = new SysMonIndicator();
        Main.panel.addToStatusArea('sysmon-topbar', this._indicator, 0, 'right');
    }

    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}
