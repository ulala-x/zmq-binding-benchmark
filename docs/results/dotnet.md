# .NET Binding Benchmark Results (Net.Zmq)

**Date:** 2025-12-17 19:05:21
**System:** Linux 6.6.87.2-microsoft-standard-WSL2
**Architecture:** x86_64
**.NET Version:** 8.0.122

## Test Configuration

- **Latency Rounds:** 50000
- **Throughput Messages:** 5000000
- **Message Sizes:** 64 1500 65536 bytes

## Results

### Message Size: 64 bytes

**Latency:**
- Average: 53.5224 us
- Message rate: 9341.89 msg/s

**Throughput:**
- Messages/sec: 2.61646E+06 msg/s
- Megabits/sec: 1339.6 Mb/s

### Message Size: 1500 bytes

**Latency:**
- Average: 60.3861 us
- Message rate: 8280.05 msg/s

**Throughput:**
- Messages/sec: 1.08925E+06 msg/s
- Megabits/sec: 13070.9 Mb/s

### Message Size: 65536 bytes

**Latency:**
- Average: 62.2341 us
- Message rate: 8034.18 msg/s

**Throughput:**
- Messages/sec: 90639.3 msg/s
- Megabits/sec: 47521.1 Mb/s


## Comparison with C++ Baseline


## Notes

- Latency is measured as round-trip time divided by 2 (one-way latency)
- Throughput measurement excludes the first message (warm-up)
- All tests use tcp://localhost for consistency
- Built with: `dotnet build -c Release` (Optimize=true, TieredCompilation=true)

## Analysis

### P/Invoke Overhead

The performance difference between C++ and .NET is primarily due to:

1. **Managed-to-Native Transitions**: Each ZeroMQ API call involves a P/Invoke call from managed .NET code to native libzmq
2. **Memory Marshaling**: Data must be marshaled between .NET's managed heap and native memory
3. **GC Impact**: Garbage collection can introduce occasional latency spikes
4. **JIT Compilation**: Although tiered compilation is enabled, there may be minor JIT overhead

### Expected Overhead by Message Size

- **Small messages (64B)**: Higher relative overhead due to fixed P/Invoke cost
- **Medium messages (1500B)**: Moderate overhead as marshaling becomes more significant
- **Large messages (65KB)**: Lower relative overhead as data transfer dominates

The overhead is generally acceptable for most real-world applications and is the cost of using .NET's productivity and safety features.

