# .NET Binding Benchmark Results (Net.Zmq)

**Date:** 2025-12-17 18:03:35
**System:** Linux 6.6.87.2-microsoft-standard-WSL2
**Architecture:** x86_64
**.NET Version:** 8.0.122

## Test Configuration

- **Latency Rounds:** 10000
- **Throughput Messages:** 1000000
- **Message Sizes:** 64 1500 65536 bytes

## Results

### Message Size: 64 bytes

**Latency:**
- Average: 51.1379 us
- Message rate: 9777.48 msg/s

**Throughput:**
- Messages/sec: 4.90956E+06 msg/s
- Megabits/sec: 2513.7 Mb/s

### Message Size: 1500 bytes

**Latency:**
- Average: 51.7553 us
- Message rate: 9660.85 msg/s

**Throughput:**
- Messages/sec: 1.33628E+06 msg/s
- Megabits/sec: 16035.3 Mb/s

### Message Size: 65536 bytes

**Latency:**
- Average: 71.1798 us
- Message rate: 7024.46 msg/s

**Throughput:**
- Messages/sec: 75643 msg/s
- Megabits/sec: 39658.7 Mb/s


## Comparison with C++ Baseline

### 64-byte Messages

| Metric | C++ Baseline | .NET (Net.Zmq) | Difference | Performance |
|--------|--------------|----------------|------------|-------------|
| **Latency** | 56.41 us | 51.14 us | -9.3% | **9.3% FASTER** ⚡ |
| **Throughput** | 5.18M msg/s | 4.91M msg/s | -5.3% | 5.3% slower |

### 1500-byte Messages

| Metric | C++ Baseline | .NET (Net.Zmq) | Difference | Performance |
|--------|--------------|----------------|------------|-------------|
| **Latency** | 53.85 us | 51.76 us | -3.9% | **3.9% FASTER** ⚡ |
| **Throughput** | 1.17M msg/s | 1.34M msg/s | +14.3% | **14.3% FASTER** ⚡ |

### 65536-byte Messages

| Metric | C++ Baseline | .NET (Net.Zmq) | Difference | Performance |
|--------|--------------|----------------|------------|-------------|
| **Latency** | 66.80 us | 71.18 us | +6.6% | 6.6% slower |
| **Throughput** | 111K msg/s | 76K msg/s | -31.9% | 31.9% slower |

### Analysis

**Surprising Results:** The .NET implementation actually **outperforms** C++ in small and medium message sizes for latency and medium messages for throughput!

**Possible Explanations:**

1. **Net.Zmq Optimizations**: The Net.Zmq binding may have optimized P/Invoke marshaling for small messages
2. **Zero-Copy Techniques**: Efficient memory handling that minimizes data copying
3. **JIT Optimizations**: .NET's JIT compiler with tiered compilation produces highly optimized machine code
4. **Measurement Variance**: System load and WSL2 virtualization may affect results
5. **Different libzmq Versions**: The two bindings might use different libzmq implementations or versions

**Large Message Performance**: The 32% throughput degradation for 65KB messages suggests:
- Memory marshaling overhead becomes significant for large buffers
- GC pressure from large allocations
- This is expected and acceptable for most use cases


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

