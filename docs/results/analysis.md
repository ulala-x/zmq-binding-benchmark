# ZeroMQ Binding Performance Comparison

## Summary

**Baseline:** C++ (cppzmq)
**Test Date:** 2025-12-17
**Platform:** Linux x86_64

## Latency Comparison (REQ-REP)

Lower is better. Values show average round-trip latency in microseconds.

### Message Size: 64 Bytes

| Language | Latency (μs) | vs C++ | Overhead |
|----------|-------------|--------|----------|
| C++ (baseline) | 56.406 | 100% | - |
| .NET | 71.478 | 78.9% | +26.7% |
| Node.js | 85.689 | 65.8% | +51.9% |

### Message Size: 1500 Bytes

| Language | Latency (μs) | vs C++ | Overhead |
|----------|-------------|--------|----------|
| C++ (baseline) | 53.846 | 100% | - |
| .NET | 51.727 | 104.1% | -3.9% |
| Node.js | 90.930 | 59.2% | +68.9% |

### Message Size: 65536 Bytes

| Language | Latency (μs) | vs C++ | Overhead |
|----------|-------------|--------|----------|
| C++ (baseline) | 66.802 | 100% | - |
| .NET | 72.329 | 92.4% | +8.3% |
| Node.js | 110.702 | 60.3% | +65.7% |

## Throughput Comparison (PUSH-PULL)

Higher is better. Values show messages per second.

### Message Size: 64 Bytes

| Language | Throughput (msg/s) | Bandwidth (Mb/s) | vs C++ |
|----------|-------------------|-----------------|--------|
| C++ (baseline) | 5,184,380 | 2,654.400 | 100% |
| .NET | 2,579,750 | 1,320.800 | 201.0% |
| Node.js | 861,377 | 441.025 | 601.9% |

### Message Size: 1500 Bytes

| Language | Throughput (msg/s) | Bandwidth (Mb/s) | vs C++ |
|----------|-------------------|-----------------|--------|
| C++ (baseline) | 1,169,640 | 14,035.700 | 100% |
| .NET | 1,061,950 | 12,743.500 | 110.2% |
| Node.js | 612,412 | 7,348.940 | 191.0% |

### Message Size: 65536 Bytes

| Language | Throughput (msg/s) | Bandwidth (Mb/s) | vs C++ |
|----------|-------------------|-----------------|--------|
| C++ (baseline) | 111,149 | 58,274.100 | 100% |
| .NET | 87,773 | 46,018.400 | 126.6% |
| Node.js | 96,482 | 50,584.258 | 115.2% |

## Key Findings

### 1. .NET Performance Characteristics

**.NET shows expected P/Invoke overhead**, particularly for small messages:

- **64B messages**: +26.7% latency, 50.2% lower throughput (fixed P/Invoke cost dominates)
- **1500B messages**: -3.9% latency (slightly faster!), 9.2% lower throughput (data transfer balances overhead)
- **65KB messages**: +8.3% latency, 21.0% lower throughput (memory operations dominate)

**Key factors:**
- P/Invoke call overhead for each ZeroMQ API call
- Message object creation and disposal
- Memory marshaling between managed and native memory
- Minimal GC pressure with proper Message object disposal

### 2. Node.js Overhead Pattern

Node.js demonstrates overhead characteristic of N-API bindings:

- **51.9% to 68.9% higher latency** across message sizes

**Key factors:**
- N-API bridge crossing for each operation
- Promise creation/resolution overhead from async/await
- V8 garbage collector and memory management
- Event loop integration adds microtask queue processing

### 3. Message Size Impact

**Small Messages (64B):**
- Fixed overhead (call cost, marshaling) dominates
- Per-call overhead is most visible

**Medium Messages (1500B):**
- Balanced between overhead and data transfer
- Typical Ethernet MTU size

**Large Messages (65KB):**
- Data transfer dominates, relative overhead decreases
- Memory copying becomes significant factor

## Performance Recommendations

### Choose C++ When:
- Absolute maximum performance is required
- Sub-microsecond latency matters
- Building low-level infrastructure
- Working in resource-constrained environments

### Choose .NET When:
- Building enterprise applications
- Need excellent performance with high productivity
- Want type safety and modern language features
- Latency < 100μs is acceptable

### Choose Node.js When:
- Building I/O-bound microservices
- Event-driven or real-time applications
- Need integration with Node.js ecosystem
- Latency < 1ms is acceptable

## Technical Details

### Measurement Methodology

**Latency Test:**
- Pattern: REQ/REP (request-reply)
- Measurement: Round-trip time ÷ 2
- Rounds: 10,000
- Timing: High-resolution timers

**Throughput Test:**
- Pattern: PUSH/PULL (unidirectional)
- Measurement: Messages per second
- Count: 1,000,000 messages
- Warm-up: First message excluded

### Binding Architectures

| Aspect | C++ (cppzmq) | .NET (Net.Zmq) | Node.js (zeromq.js) |
|--------|--------------|----------------|---------------------|
| **Binding Type** | Header-only | P/Invoke | N-API |
| **Memory Model** | Manual/RAII | GC with Span<T> | GC with Buffer |
| **Async Model** | Blocking | Blocking | Native async |
| **Zero-Copy** | Full | Partial (Span) | Partial (Buffer) |

---

**Raw data:** `benchmark_data.json`
**Generated:** 2025-12-17 18:57:08
**Note:** .NET results corrected to use Message objects (matching C++ zmq::message_t behavior)
