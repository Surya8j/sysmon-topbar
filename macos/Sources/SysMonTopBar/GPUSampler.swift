import Foundation
import IOKit

/// Whole-GPU utilization from the IOAccelerator registry entry's
/// `PerformanceStatistics` dictionary. macOS exposes no public per-core GPU
/// counters, so unlike the CPU this is a single number.
final class GPUSampler {
    // Key names differ across GPU drivers; probe in order.
    private static let utilizationKeys = [
        "Device Utilization %", // Apple Silicon (AGXAccelerator)
        "GPU Activity(%)",      // some Intel-era drivers
    ]

    private let entry: io_registry_entry_t
    let coreCount: Int?

    init() {
        entry = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOAccelerator")
        )
        if entry != 0,
           let count = IORegistryEntryCreateCFProperty(
               entry, "gpu-core-count" as CFString, kCFAllocatorDefault, 0
           )?.takeRetainedValue() as? Int {
            coreCount = count
        } else {
            coreCount = nil
        }
    }

    deinit {
        if entry != 0 { IOObjectRelease(entry) }
    }

    /// Returns utilization in 0...1, or nil when the driver publishes no
    /// readable statistics (the GPU view is then skipped entirely).
    func sample() -> Double? {
        guard entry != 0,
              let stats = IORegistryEntryCreateCFProperty(
                  entry, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0
              )?.takeRetainedValue() as? [String: Any]
        else { return nil }

        for key in Self.utilizationKeys {
            if let pct = stats[key] as? Int {
                return min(max(Double(pct) / 100, 0), 1)
            }
        }
        return nil
    }
}
