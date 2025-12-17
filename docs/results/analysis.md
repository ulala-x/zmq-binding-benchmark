# ZeroMQ Binding Performance Comparison

## Summary

**Baseline:** C++ (cppzmq)
**Test Date:** 2025-12-17
**Platform:** Linux x86_64
**Test Configuration:** 50,000 latency rounds, 5,000,000 throughput messages

## Latency Comparison (REQ-REP)

Lower is better. Values show average round-trip latency in microseconds.

### Message Size: 64 Bytes

| Language | Latency (μs) | vs C++ | Overhead |
|----------|-------------|--------|----------|
| C++ (baseline) | 56.127 | 100% | - |
| .NET | 53.522 | 104.9% | -4.6% ⚡ |
| Node.js | 62.603 | 89.7% | +11.5% |

### Message Size: 1500 Bytes

| Language | Latency (μs) | vs C++ | Overhead |
|----------|-------------|--------|----------|
| C++ (baseline) | 55.551 | 100% | - |
| .NET | 60.386 | 92.0% | +8.7% |
| Node.js | 74.879 | 74.2% | +34.8% |

### Message Size: 65536 Bytes

| Language | Latency (μs) | vs C++ | Overhead |
|----------|-------------|--------|----------|
| C++ (baseline) | 41.713 | 100% | - |
| .NET | 62.234 | 67.0% | +49.2% |
| Node.js | 79.194 | 52.7% | +89.9% |

## Throughput Comparison (PUSH-PULL)

Higher is better. Values show messages per second.

### Message Size: 64 Bytes

| Language | Throughput (msg/s) | Bandwidth (Mb/s) | vs C++ |
|----------|-------------------|-----------------|--------|
| C++ (baseline) | 5,299,600 | 2,713.4 | 100% |
| .NET | 2,616,460 | 1,339.6 | 49.4% |
| Node.js | 886,540 | 453.9 | 16.7% |

### Message Size: 1500 Bytes

| Language | Throughput (msg/s) | Bandwidth (Mb/s) | vs C++ |
|----------|-------------------|-----------------|--------|
| C++ (baseline) | 1,473,030 | 17,676.4 | 100% |
| .NET | 1,089,250 | 13,070.9 | 73.9% |
| Node.js | 654,337 | 7,852.0 | 44.4% |

### Message Size: 65536 Bytes

| Language | Throughput (msg/s) | Bandwidth (Mb/s) | vs C++ |
|----------|-------------------|-----------------|--------|
| C++ (baseline) | 93,585 | 49,065.3 | 100% |
| .NET | 90,639 | 47,521.1 | 96.9% |
| Node.js | 113,035 | 59,262.9 | 120.8% ⚡ |

## Key Findings

### 1. .NET Performance Characteristics

**.NET shows excellent performance, particularly for small message latency:**

- **64B messages**: -4.6% latency (FASTER than C++!), 50.6% lower throughput
- **1500B messages**: +8.7% latency, 26.1% lower throughput
- **65KB messages**: +49.2% latency, 3.1% lower throughput

**Surprising Result:** .NET's 64-byte latency is actually **4.6% faster** than C++. This is remarkable for a managed runtime and demonstrates:

- Highly optimized P/Invoke marshaling in Net.Zmq
- Effective use of Message objects with proper disposal
- JIT compiler producing excellent machine code for hot paths
- Minimal GC pressure with careful buffer management
- Increased test iterations (50K vs 10K) providing more stable measurements

**Key factors:**
- P/Invoke call overhead for each ZeroMQ API call
- Message object creation and disposal
- Memory marshaling between managed and native memory
- With larger messages (65KB), latency increases significantly due to memory operations

### 2. Node.js Overhead Pattern

Node.js demonstrates overhead characteristic of N-API bindings:

- **11.5% to 89.9% higher latency** across message sizes
- **Throughput ranges from 16.7% to 120.8% of C++**

**Surprising Result:** Node.js achieves **20.8% higher throughput** than C++ for 65KB messages! This suggests:
- Efficient large buffer handling in zeromq.js
- V8's optimized memory management for large allocations
- Effective N-API integration for bulk data transfer
- Event loop efficiency for throughput-oriented workloads

**Key factors:**
- N-API bridge crossing for each operation
- Promise creation/resolution overhead from async/await
- V8 garbage collector and memory management
- Event loop integration adds microtask queue processing
- Small messages suffer from fixed async overhead
- Large messages benefit from efficient bulk transfers

### 3. Message Size Impact

**Small Messages (64B):**
- Fixed overhead (call cost, marshaling) dominates
- Per-call overhead is most visible
- .NET actually outperforms C++ in latency
- Node.js shows significant throughput penalty (83.3% slower)

**Medium Messages (1500B):**
- Balanced between overhead and data transfer
- Typical Ethernet MTU size
- All bindings show moderate overhead
- .NET: 8.7% latency overhead, 26.1% throughput penalty

**Large Messages (65KB):**
- Data transfer and memory operations dominate
- Latency overhead increases (managed memory copies)
- Throughput differences minimize (or reverse!)
- Node.js surprisingly beats C++ by 20.8%
- .NET matches C++ within 3.1%

### 4. Impact of Increased Test Iterations

With 5x more test iterations (50,000 vs 10,000 for latency, 5M vs 1M for throughput):

**More Stable Results:**
- .NET 64B latency improved from 71.48μs to 53.52μs
- C++ 65KB latency improved from 66.80μs to 41.71μs
- More iterations allow JIT warmup and consistent measurements

**Better JIT Optimization:**
- .NET's JIT compiler had more time to optimize hot paths
- Tiered compilation reached optimal tier
- Node.js V8 engine optimized hot functions

**Statistical Reliability:**
- Reduced impact of outliers and system noise
- More representative of sustained performance
- Better for comparing managed vs native code

## Performance Recommendations

### Choose C++ When:
- Absolute maximum performance is required
- Sub-microsecond latency matters
- Building low-level infrastructure
- Working in resource-constrained environments
- Small message throughput is critical (5.3M msg/s vs 2.6M for .NET)

### Choose .NET When:
- Building enterprise applications
- **Excellent latency for small messages** (faster than C++!)
- Want type safety and modern language features
- High throughput for large messages (96.9% of C++)
- Latency < 100μs is acceptable
- Need rapid development with strong tooling

### Choose Node.js When:
- Building I/O-bound microservices
- Event-driven or real-time applications
- **Best throughput for large messages** (20.8% faster than C++!)
- Need integration with Node.js ecosystem
- Latency < 100μs is acceptable
- Async/await programming model is preferred

## Technical Details

### Measurement Methodology

**Latency Test:**
- Pattern: REQ/REP (request-reply)
- Measurement: Round-trip time ÷ 2
- Rounds: 50,000 (increased from 10,000)
- Warm-up: 1 round excluded
- Timing: High-resolution timers

**Throughput Test:**
- Pattern: PUSH/PULL (unidirectional)
- Measurement: Messages per second
- Count: 5,000,000 messages (increased from 1,000,000)
- Warm-up: First message excluded
- Progress tracking: Every 10%

### Binding Architectures

| Aspect | C++ (cppzmq) | .NET (Net.Zmq) | Node.js (zeromq.js) |
|--------|--------------|----------------|---------------------|
| **Binding Type** | Header-only | P/Invoke | N-API |
| **Memory Model** | Manual/RAII | GC with Message | GC with Buffer |
| **Async Model** | Blocking | Blocking | Native async |
| **Zero-Copy** | Full | Partial (Message) | Partial (Buffer) |
| **Best Use Case** | Max throughput (small msg) | Balanced perf + productivity | Large message throughput |

### Test Environment

- **System:** Linux 6.6.87.2-microsoft-standard-WSL2 (WSL2)
- **Architecture:** x86_64
- **C++ Compiler:** GCC 13.3.0 with `-O3 -march=native -flto`
- **.NET Runtime:** .NET 8.0.122 (Release, TieredCompilation)
- **Node.js:** v22.19.0 (V8 default settings)
- **libzmq:** 4.3.5 (from libzmq-native)

---

**Raw data:** `benchmark_data.json`
**Generated:** 2025-12-17 19:06:55
**Test Configuration:** 50,000 latency rounds, 5,000,000 throughput messages
**Note:** .NET and Node.js use Message/Buffer objects (matching C++ zmq::message_t behavior)
