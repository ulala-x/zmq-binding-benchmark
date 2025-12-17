# Testing Methodology

**Document Version:** 1.0
**Last Updated:** 2025-12-17
**Applies to:** All language implementations

## Overview

This document describes the methodology used to ensure fair and reproducible performance comparison between different ZeroMQ language bindings. The goal is to measure binding overhead in isolation, not network or hardware performance.

## Table of Contents

- [Test Environment](#test-environment)
- [Test Patterns](#test-patterns)
- [Fairness Principles](#fairness-principles)
- [Measurement Techniques](#measurement-techniques)
- [Limitations](#limitations)
- [Result Interpretation](#result-interpretation)

## Test Environment

### Platform Configuration

All tests are conducted on a consistent platform to ensure reproducibility:

**Operating System:**
- Linux 6.6.87.2-microsoft-standard-WSL2
- WSL2 on Windows 11 (x86_64 architecture)
- Single-node testing (no network I/O)

**Network Configuration:**
- Transport: TCP over localhost (`tcp://127.0.0.1`)
- Interface: Loopback (no physical network latency)
- MTU: Default system MTU (typically 65536 for localhost)
- No firewall interference

**System Resources:**
- Isolated testing (minimal background processes)
- No CPU throttling or power management
- Single-threaded execution (no parallelism)

### Build Configurations

Each language is built with maximum optimizations enabled:

#### C++ (Baseline)

```bash
Compiler: GCC 13.3.0
Flags: -O3 -march=native -flto -DNDEBUG
Build System: CMake 3.22+
Standard: C++17
libzmq: 4.3.5 (from libzmq-native)
```

**Optimization flags:**
- `-O3`: Maximum optimization level
- `-march=native`: CPU-specific optimizations
- `-flto`: Link-time optimization
- `-DNDEBUG`: Disable assertions

#### .NET

```bash
Runtime: .NET 8.0.122
Configuration: Release
Platform: linux-x64
Optimize: true
TieredCompilation: true
```

**Runtime settings:**
- Release build (no debug symbols)
- Tiered JIT compilation enabled
- Server GC mode (automatic)
- Span<T> for zero-copy scenarios

#### Node.js

```bash
Runtime: Node.js v22.19.0
V8 Version: 12.4.254.20
Binding: zeromq ^6.0.0 (N-API)
Build: Default npm install (Release mode)
```

**Runtime characteristics:**
- V8 JIT compilation enabled
- Default garbage collector settings
- Native addon built in Release mode
- No --inspect or debugging flags

### libzmq Consistency

**Critical requirement:** All implementations use the **same** libzmq native library:

```bash
Source: https://github.com/ulala-x/libzmq-native
Version: libzmq 4.3.5 + libsodium 1.0.18
Build: Static library, optimized for x64
```

**Why this matters:**
- Different libzmq versions have different performance characteristics
- Using the same native library isolates binding overhead
- Eliminates variables from native library implementation

## Test Patterns

### Pattern 1: Latency Test (REQ-REP)

#### Purpose

Measure round-trip latency for request-reply communication pattern. This tests:
- Socket send/receive overhead
- Serialization/deserialization costs
- Binding call overhead
- Memory allocation patterns

#### Configuration

```
Pattern: Request-Reply (synchronous)
Client Socket: REQ (zmq.SocketType.REQ)
Server Socket: REP (zmq.SocketType.REP)
Bind Address: tcp://127.0.0.1:5555
Connection: Single client to single server
```

#### Test Process

1. **Server Setup** (`local-lat`):
   ```
   - Create REP socket
   - Bind to tcp://127.0.0.1:5555
   - Enter receive-send loop
   ```

2. **Client Execution** (`remote-lat`):
   ```
   - Create REQ socket
   - Connect to tcp://127.0.0.1:5555
   - Start high-resolution timer
   - Loop N times:
       - Send message
       - Receive reply
   - Stop timer
   - Calculate latency: (elapsed / N) / 2
   ```

3. **Rounds**: 10,000 iterations (no warm-up phase)
   - First few messages act as implicit warm-up
   - Steady-state performance measured across all rounds

#### Measurement Method

**Timing:**
```
Round-trip time = time_after_all_receives - time_before_first_send
One-way latency = round_trip_time / (2 * message_count)
```

**Why divide by 2:**
- Round-trip includes both send and receive
- We report one-way latency for clarity
- Standard practice in network benchmarks

**High-resolution timers:**
- C++: `std::chrono::high_resolution_clock` (nanosecond precision)
- .NET: `System.Diagnostics.Stopwatch` (nanosecond precision)
- Node.js: `process.hrtime.bigint()` (nanosecond precision)

#### Result Format

```
Latency Test Results:
Message size: 64 bytes
Message count: 10000
Total time: 1.234567 s
Average latency: 56.789 μs
```

### Pattern 2: Throughput Test (PUSH-PULL)

#### Purpose

Measure unidirectional throughput for pipeline pattern. This tests:
- Sustained message rate
- Buffer management efficiency
- Memory allocation under load
- Backpressure handling

#### Configuration

```
Pattern: Pipeline (unidirectional)
Sender Socket: PUSH (zmq.SocketType.PUSH)
Receiver Socket: PULL (zmq.SocketType.PULL)
Bind Address: tcp://127.0.0.1:5556
Connection: Single sender to single receiver
```

#### Test Process

1. **Receiver Setup** (`local-thr`):
   ```
   - Create PULL socket
   - Bind to tcp://127.0.0.1:5556
   - Receive first message (synchronization)
   - Start timer
   - Receive remaining messages
   - Stop timer
   - Calculate throughput
   ```

2. **Sender Execution** (`remote-thr`):
   ```
   - Create PUSH socket
   - Connect to tcp://127.0.0.1:5556
   - Send N messages as fast as possible
   ```

3. **Messages**: 1,000,000 total
   - First message acts as synchronization point
   - Throughput calculated over remaining 999,999 messages

#### Measurement Method

**Timing:**
```
elapsed_time = time_after_last_receive - time_after_first_receive
throughput = (message_count - 1) / elapsed_time (messages/second)
megabits_per_second = (throughput * message_size * 8) / 1_000_000
```

**Why exclude first message:**
- First message triggers receiver to start timer
- Eliminates connection establishment overhead
- Measures steady-state performance only

**Synchronization:**
- Sender starts immediately after connection
- Receiver waits for first message before timing
- This is the standard libzmq benchmark approach

#### Result Format

```
Throughput Test Results:
Message size: 64 bytes
Message count: 1000000
Total time: 0.123456 s
Throughput: 8101234 msg/s
Megabits per second: 4147.83 Mb/s
```

### Message Sizes

Three representative message sizes are tested:

| Size | Bytes | Purpose | Characteristics |
|------|-------|---------|-----------------|
| **Small** | 64 | Protocol overhead dominant | Tests binding call overhead |
| **Medium** | 1500 | Typical Ethernet MTU | Balanced test case |
| **Large** | 65536 | 64 KB bulk transfer | Tests zero-copy efficiency |

**Why these sizes:**
- **64 bytes**: Common for control messages, headers, small payloads
- **1500 bytes**: Standard Ethernet MTU, typical application message
- **65536 bytes**: Large payload, tests memory handling and zero-copy

## Fairness Principles

### 1. Identical Logic

All implementations follow the **exact same** algorithm:

**Latency test:**
```
1. Create socket
2. Connect/bind
3. Start timer
4. Loop N times: send + receive
5. Stop timer
6. Calculate: elapsed / N / 2
```

**Throughput test:**
```
Receiver:
1. Create socket
2. Bind
3. Receive first message
4. Start timer
5. Receive N-1 messages
6. Stop timer
7. Calculate: (N-1) / elapsed

Sender:
1. Create socket
2. Connect
3. Send N messages
```

### 2. Identical Message Sizes

Each test uses **exactly the same** byte count:
- C++: `std::vector<char>(size)`
- .NET: `byte[size]`
- Node.js: `Buffer.alloc(size)`

No compression, serialization, or encoding differences.

### 3. Identical Timing Measurement

All implementations measure at the **same points**:

**Start:** Immediately before first send operation
**Stop:** Immediately after last receive operation

Timer placement is critical for fair comparison.

### 4. Optimization Level Consistency

Each language uses its **maximum optimization** settings:

- C++: `-O3 -march=native -flto`
- .NET: Release build with tiered JIT
- Node.js: Default V8 optimizations

No debug builds or profiling overhead.

### 5. Measurement Precision

All implementations use **nanosecond-precision** timers:

- C++: `std::chrono::high_resolution_clock`
- .NET: `System.Diagnostics.Stopwatch`
- Node.js: `process.hrtime.bigint()`

Consistent units (microseconds) in output.

## Measurement Techniques

### Timer Selection

**Requirements:**
- Monotonic (not affected by system clock changes)
- High resolution (nanosecond precision)
- Low overhead (< 100ns per call)

**Implementation-specific:**

```cpp
// C++
auto start = std::chrono::high_resolution_clock::now();
// ... test code ...
auto end = std::chrono::high_resolution_clock::now();
auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
```

```csharp
// .NET
var sw = Stopwatch.StartNew();
// ... test code ...
sw.Stop();
var elapsed = sw.Elapsed.TotalMicroseconds;
```

```javascript
// Node.js
const start = process.hrtime.bigint();
// ... test code ...
const end = process.hrtime.bigint();
const elapsed = Number(end - start) / 1000; // nanoseconds to microseconds
```

### Warm-up Strategy

**No explicit warm-up phase** is used because:

1. **First few messages act as implicit warm-up:**
   - JIT compilation (for .NET and Node.js)
   - CPU cache warming
   - Connection establishment

2. **10,000 iterations amortize warm-up:**
   - First 100 messages may be slower
   - Averaged over 10,000, impact is < 1%
   - Represents real-world mixed warm/cold performance

3. **Consistency across implementations:**
   - All languages use same approach
   - No arbitrary warm-up duration

### Statistical Considerations

**Single run per test:**
- Each test runs once per message size
- Results are deterministic on localhost
- Network variance is eliminated

**Why not multiple runs:**
- Localhost has minimal variance (< 1%)
- Multiple runs would show same results
- Single run is sufficient for binding comparison

**Expected variance:**
- Latency: ±1-2 μs (due to OS scheduling)
- Throughput: ±2-5% (due to CPU load)

## Limitations

### 1. Localhost Only

**What we test:**
- Binding overhead (call cost, marshaling)
- Memory management
- Serialization/deserialization

**What we DON'T test:**
- Network latency
- Packet loss handling
- Network congestion
- Physical network bandwidth

**Impact:** Results show binding overhead, not network performance.

### 2. Single-Threaded

**Configuration:**
- One sender thread
- One receiver thread
- No concurrent sockets

**What we DON'T test:**
- Thread safety overhead
- Multi-threaded scaling
- Socket sharing patterns
- Context contention

**Impact:** Results show best-case single-threaded performance.

### 3. No Security (CURVE)

**Configuration:**
- Plain TCP transport
- No encryption
- No authentication

**What we DON'T test:**
- CURVE encryption overhead
- Key exchange performance
- Authentication costs

**Impact:** Results show base protocol performance without security overhead.

### 4. Default Socket Options

**Configuration:**
- Default send/receive high water marks
- Default buffer sizes
- Default socket options

**What we DON'T test:**
- Tuned socket performance
- Custom buffer sizes
- Advanced socket options

**Impact:** Results show out-of-the-box performance.

### 5. Synchronous Only

**Configuration:**
- Blocking send/receive
- No polling or async I/O

**What we DON'T test:**
- Async/await performance (except Node.js natural pattern)
- Polling overhead
- Event loop integration

**Impact:** Results show synchronous blocking performance.

## Result Interpretation

### Latency Results

**What the numbers mean:**

```
Average latency: 56.4 μs
```

This represents:
- **One-way** latency (send OR receive)
- Time from application buffer to receiving application buffer
- Includes: binding overhead + libzmq overhead + kernel overhead

**Performance categories:**

| Latency | Category | Use Cases |
|---------|----------|-----------|
| < 10 μs | Ultra-low | High-frequency trading, real-time control |
| 10-50 μs | Very low | Low-latency microservices, gaming |
| 50-100 μs | Low | Enterprise messaging, RPC |
| 100-500 μs | Moderate | Web services, general applications |
| > 500 μs | High | Batch processing, background tasks |

**Comparing to baseline:**

```
.NET: 51.1 μs vs C++ 56.4 μs = -9.3% (faster)
```

- **Negative percentage = faster** than baseline
- **Positive percentage = slower** than baseline
- Consider ±5% as negligible difference

### Throughput Results

**What the numbers mean:**

```
Throughput: 5.18M msg/s
```

This represents:
- Sustained message rate (messages per second)
- Best-case unidirectional throughput
- Includes: binding overhead + libzmq overhead

**Performance categories:**

| Throughput | Category | Use Cases |
|------------|----------|-----------|
| > 10M msg/s | Ultra-high | High-frequency data feeds |
| 1-10M msg/s | High | Real-time analytics, event streaming |
| 100K-1M msg/s | Moderate | Application messaging |
| < 100K msg/s | Low | Batch processing, periodic updates |

**Converting to bandwidth:**

```
Megabits per second = (throughput * message_size * 8) / 1,000,000
```

Example for 1500-byte messages at 1.17M msg/s:
```
(1,170,000 * 1500 * 8) / 1,000,000 = 14,040 Mb/s = 14 Gb/s
```

### Overhead Calculation

**Binding overhead:**

```
Overhead = (Language_Time - Baseline_Time) / Baseline_Time * 100%
```

Examples:
```
.NET latency overhead = (51.1 - 56.4) / 56.4 * 100% = -9.3% (faster!)
Node.js latency overhead = (85.7 - 56.4) / 56.4 * 100% = +51.9% (slower)
```

**Interpreting overhead:**

| Overhead | Impact | Acceptable? |
|----------|--------|-------------|
| < 5% | Negligible | Yes - essentially equivalent |
| 5-20% | Minor | Yes - usually acceptable |
| 20-50% | Moderate | Depends - evaluate trade-offs |
| > 50% | Significant | Carefully consider use case |

### Expected Trends

**Message size vs latency:**
- Small messages: Binding overhead dominates
- Large messages: Data transfer dominates
- Expected: Latency increases with message size

**Message size vs throughput:**
- Small messages: More messages per second, less bandwidth
- Large messages: Fewer messages per second, more bandwidth
- Expected: Throughput (msg/s) decreases as message size increases

**Binding overhead:**
- Fixed overhead (call cost): ~10-50 μs per call
- Variable overhead (marshaling): Scales with message size
- Expected: Fixed overhead matters more for small messages

## Reproducibility

### Running Tests Yourself

To reproduce these results:

```bash
# Validate environment
./scripts/validate.sh

# Run all benchmarks
./scripts/run-all.sh

# Results will be in docs/results/
```

### Expected Variance

**Acceptable variance:**
- Latency: ±2-3 μs (3-5%)
- Throughput: ±5-10% (depending on CPU load)

**If variance is higher:**
- Check for background processes
- Verify CPU is not throttled
- Ensure adequate cooling
- Run multiple times and average

### Reporting Results

When reporting results, include:
- Operating system and version
- CPU model and clock speed
- Compiler/runtime versions
- libzmq version
- Date and time of tests

## References

- [ZeroMQ Performance Documentation](http://wiki.zeromq.org/area:perf)
- [libzmq Performance Tests Source](https://github.com/zeromq/libzmq/tree/master/perf)
- [ZeroMQ Guide - Chapter 7: Advanced Architecture](https://zguide.zeromq.org/docs/chapter7/)
- [High-Resolution Timing Best Practices](https://www.intel.com/content/www/us/en/developer/articles/technical/performance-measurement-techniques.html)

---

**Document Maintenance:**
- Update this document when methodology changes
- Version control all methodology changes
- Link to specific commit for result reproducibility
