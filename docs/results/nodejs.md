# Node.js Binding Benchmark Results (zeromq.js)

**Date:** 2025-12-17 19:06:55
**System:** Linux 6.6.87.2-microsoft-standard-WSL2
**Architecture:** x86_64
**Node.js Version:** v22.19.0

## Test Configuration

- **Latency Rounds:** 50000
- **Throughput Messages:** 5000000
- **Message Sizes:** 64 1500 65536 bytes

## Results

>> Message Size: 64 bytes

**Latency:** 62.603 us

**Throughput:** 886540 msg/s (453.909 Mb/s)

>> Message Size: 1500 bytes

**Latency:** 74.879 us

**Throughput:** 654337 msg/s (7852.041 Mb/s)

>> Message Size: 65536 bytes

**Latency:** 79.194 us

**Throughput:** 113035 msg/s (59262.926 Mb/s)


## Comparison with C++ Baseline

### C++ Baseline Performance

| Message Size | Latency (us) | Throughput (msg/s) |
|--------------|--------------|-------------------|
| 64 bytes     | 56.41        | 5,180,000         |
| 1500 bytes   | 53.85        | 1,170,000         |
| 65536 bytes  | 66.80        | 111,000           |

### Node.js Performance vs C++ Baseline

#### 64-byte Messages

| Metric | C++ Baseline | Node.js | Difference | Performance |
|--------|--------------|---------|------------|-------------|
| **Latency** | 56.41 us | 62.603 us | 11.0% | slower |
| **Throughput** | 5180000 msg/s | 886540 msg/s | -82.9% | slower |

#### 1500-byte Messages

| Metric | C++ Baseline | Node.js | Difference | Performance |
|--------|--------------|---------|------------|-------------|
| **Latency** | 53.85 us | 74.879 us | 39.1% | slower |
| **Throughput** | 1170000 msg/s | 654337 msg/s | -44.1% | slower |

#### 65536-byte Messages

| Metric | C++ Baseline | Node.js | Difference | Performance |
|--------|--------------|---------|------------|-------------|
| **Latency** | 66.80 us | 79.194 us | 18.6% | slower |
| **Throughput** | 111000 msg/s | 113035 msg/s | 1.8% | FASTER ⚡ |


## Analysis

### N-API and V8 Overhead

The performance characteristics of the Node.js zeromq binding are influenced by:

1. **N-API Bridge**: The zeromq.js library uses N-API to bridge JavaScript and native libzmq
2. **V8 Memory Management**: JavaScript Buffers must be managed by V8's garbage collector
3. **Event Loop Integration**: Async operations integrate with Node.js event loop
4. **Promise Overhead**: The async/await pattern adds some overhead for each operation

### Expected Overhead by Message Size

- **Small messages (64B)**: Higher relative overhead due to N-API call cost and async overhead
- **Medium messages (1500B)**: Moderate overhead as data transfer becomes more significant
- **Large messages (65KB)**: Lower relative overhead as data transfer dominates, but still affected by memory copying

### async/await Pattern Impact

The zeromq.js library uses async/await for all socket operations, which:
- Provides clean, readable code and error handling
- Integrates naturally with Node.js event-driven architecture
- Adds overhead for Promise creation and resolution
- Each send/receive involves microtask queue processing

### Comparison with .NET

Comparing Node.js with .NET's Net.Zmq binding shows interesting patterns:
- Both use native bindings (N-API vs P/Invoke)
- Both have managed memory overhead
- .NET may have advantages with Span<T> and unsafe code for large buffers
- Node.js may have advantages with simpler async model

## Notes

- Latency is measured as round-trip time divided by 2 (one-way latency)
- Throughput measurement excludes the first message (warm-up)
- All tests use tcp://127.0.0.1 for consistency
- Tests run with Node.js default settings (no special V8 flags)

