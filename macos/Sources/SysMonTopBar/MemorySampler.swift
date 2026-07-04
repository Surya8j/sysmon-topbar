import Darwin

struct MemoryStats {
    var used: UInt64 = 0
    var total: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0

    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

/// RAM and swap usage via `host_statistics64` and sysctl.
final class MemorySampler {
    private let total: UInt64 = {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }()

    func sample() -> MemoryStats {
        var stats = MemoryStats(total: total)

        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            // active + wired + compressed approximates Activity Monitor's "Memory Used".
            let pages = UInt64(vmStats.active_count)
                + UInt64(vmStats.wire_count)
                + UInt64(vmStats.compressor_page_count)
            stats.used = pages * UInt64(vm_page_size)
        }

        var swap = xsw_usage()
        var len = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &len, nil, 0) == 0 {
            stats.swapUsed = swap.xsu_used
            stats.swapTotal = swap.xsu_total
        }
        return stats
    }
}
