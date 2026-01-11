import Foundation

class PerformanceMonitor {
    /// Returns the CPU usage percentage of the current process.
    func getCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        // Get threads for the current task
        let kerr = task_threads(mach_task_self_, &threadList, &threadCount)
        if kerr != KERN_SUCCESS {
            return 0.0
        }
        
        defer {
            if let list = threadList {
                let size = vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: list), size)
            }
        }
        
        var totalUsage: Double = 0.0
        
        // Sum up CPU usage across all threads
        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let res = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                    thread_info(threadList![i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            
            if res == KERN_SUCCESS {
                if (threadInfo.flags & TH_FLAGS_IDLE) == 0 {
                    totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                }
            }
        }
        
        return totalUsage * 100.0
    }
}
