import Darwin

/// Per-core CPU usage via Mach `host_processor_info`, computed as the delta
/// between consecutive samples (the raw counters are cumulative ticks).
final class CPUSampler {
    private struct Ticks {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32
    }

    private var previous: [Ticks] = []

    /// Returns one usage value in 0...1 per core. The first call returns
    /// zeros because no delta exists yet.
    func sample() -> [Double] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount
        )
        guard kr == KERN_SUCCESS, let info else {
            return Array(repeating: 0, count: previous.count)
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        var current: [Ticks] = []
        current.reserveCapacity(Int(cpuCount))
        var usages: [Double] = []
        usages.reserveCapacity(Int(cpuCount))

        for core in 0..<Int(cpuCount) {
            let base = core * Int(CPU_STATE_MAX)
            let ticks = Ticks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            )
            current.append(ticks)

            guard core < previous.count else {
                usages.append(0)
                continue
            }
            let prev = previous[core]
            // Counters wrap at UInt32.max; wrapping subtraction keeps deltas valid.
            let busy = (ticks.user &- prev.user)
                &+ (ticks.system &- prev.system)
                &+ (ticks.nice &- prev.nice)
            let total = busy &+ (ticks.idle &- prev.idle)
            usages.append(total > 0 ? Double(busy) / Double(total) : 0)
        }

        previous = current
        return usages
    }
}
