# Frequently Asked Questions

**Document Version:** 1.0
**Last Updated:** 2025-12-17

## Table of Contents

- [General Questions](#general-questions)
- [Performance Questions](#performance-questions)
- [Technical Questions](#technical-questions)
- [Troubleshooting](#troubleshooting)
- [Contributing Questions](#contributing-questions)

## General Questions

### Why this benchmark?

**Q: Why create another ZeroMQ benchmark?**

A: Existing benchmarks focus on libzmq itself, not binding overhead. This project isolates the performance cost of language bindings by:
- Using the **same libzmq version** across all languages
- Testing on **localhost** to eliminate network variance
- Following **identical test patterns**
- Using **high-precision timing**

This reveals the true overhead of calling ZeroMQ from different languages.

---

### What does this measure?

**Q: What exactly are you measuring?**

A: We measure **binding overhead**, which includes:
- Foreign function interface (FFI) crossing cost
- Memory marshaling between language runtime and native code
- Object allocation and garbage collection overhead
- Language-specific async/await or promise overhead
- Type conversion and safety checks

We **do not** measure:
- Network latency (tests run on localhost)
- libzmq implementation differences (same version for all)
- Hardware performance (same machine)

---

### Are these results representative?

**Q: Will I see the same performance in my production application?**

A: **It depends on your workload:**

**Localhost vs Real Network:**
- These tests eliminate network latency
- Real networks add 0.1-100+ ms latency
- Binding overhead becomes **less significant** with real network latency
- Example: 30μs binding overhead is negligible on a 1ms network

**Small vs Large Messages:**
- Small messages (< 1KB): Results are representative
- Large messages (> 10KB): Network bandwidth dominates
- Your results may vary based on message size distribution

**High-Throughput vs Low-Throughput:**
- High throughput (1M+ msg/s): Binding overhead matters
- Moderate throughput (< 100K msg/s): Binding overhead less important
- Consider your actual message rate

**Single-Threaded vs Multi-Threaded:**
- These tests are single-threaded
- Multi-threading adds coordination overhead
- Thread-safety mechanisms may change relative performance

---

### Which binding should I choose?

**Q: Based on these results, which language/binding should I use?**

A: **Choose based on your priorities:**

**Maximum Performance:**
- **C++** if you need absolute lowest latency (<10μs matters)
- **.NET** if you want excellent performance with high productivity
- Consider: Development time, team expertise, ecosystem

**Developer Productivity:**
- **Node.js** for event-driven architecture and JavaScript ecosystem
- **.NET** for type safety and enterprise integration
- **Python** (future) for data science and scripting
- Consider: Team skill, existing codebase, third-party libraries

**Specific Use Cases:**
- **High-frequency trading:** C++
- **Enterprise messaging:** .NET or Java (future)
- **Microservices:** Node.js or Go (future)
- **IoT devices:** C++ or Rust (future)
- **Data pipelines:** Python (future)

**Remember:** Binding performance is just one factor. Also consider:
- Team expertise and familiarity
- Existing codebase and infrastructure
- Third-party library ecosystem
- Development and maintenance costs
- Long-term support and community

---

## Performance Questions

### Why is .NET faster than C++?

**Q: How can .NET outperform C++ in some tests?**

A: Several possible explanations:

**1. JIT Optimization:**
- .NET's tiered JIT compiler profiles hot code paths
- Can perform runtime optimizations unavailable to static compilers
- May produce better code for specific CPU microarchitecture

**2. P/Invoke Optimization:**
- Modern .NET has **highly optimized P/Invoke**
- Minimal overhead for simple marshaling scenarios
- Span<T> enables zero-copy in many cases

**3. Measurement Variance:**
- Localhost tests have minimal variance but not zero
- Differences of < 10% may be within measurement noise
- Multiple runs show .NET consistently competitive

**4. Memory Layout:**
- GC may produce better cache locality for specific patterns
- Managed heap organization optimized for sequential access
- Stack allocation via stackalloc reduces heap pressure

**5. Compiler Differences:**
- C++ GCC optimizations vs .NET JIT
- Different optimization strategies may favor different patterns
- -march=native doesn't always produce best code

**Bottom Line:** .NET's excellent performance proves that managed code with good bindings can match or exceed native performance for I/O-bound workloads.

---

### Node.js overhead seems high

**Q: Why is Node.js so much slower?**

A: Node.js overhead comes from its **async architecture**, not JavaScript performance:

**Breakdown of ~35μs overhead per call:**
- N-API bridge crossing: ~10-15μs
- Promise creation: ~5-8μs
- Microtask queue scheduling: ~5-8μs
- V8 value conversions: ~3-5μs
- GC pressure from allocations: ~2-5μs

**This overhead is:**
- **Acceptable for I/O-bound apps** where network latency >> 35μs
- **Fixed per call**, so less significant for large messages
- **Trade-off for convenience** of async/await API
- **Much better than old NAN bindings** (which were 2-3x slower)

**When Node.js performance matters:**
- High message rates (> 100K msg/s)
- Small messages (< 1KB) where overhead dominates
- Low-latency requirements (< 100μs)

**When Node.js performance is fine:**
- Typical web services (1-10K msg/s)
- Network latency >> 100μs
- Developer productivity is priority

---

### Small message performance

**Q: Why do small messages show the biggest performance differences?**

A: **Fixed overhead dominates** for small messages:

```
Total time = Fixed overhead + Variable overhead

Small message (64 bytes):
C++:     0μs fixed    + 1μs data     = 1μs     (100% data)
Node.js: 35μs fixed   + 1μs data     = 36μs    (3% data, 97% overhead!)

Large message (64KB):
C++:     0μs fixed    + 20μs data    = 20μs    (100% data)
Node.js: 35μs fixed   + 22μs data    = 57μs    (39% data, 61% overhead)
```

**Fixed overhead sources:**
- Function call/return
- FFI boundary crossing
- Type conversions
- Promise/async overhead

**Variable overhead sources:**
- Memory allocation
- Buffer copying
- Serialization (if any)
- Data transfer

**As message size increases:**
- Variable overhead grows
- Fixed overhead stays constant
- **Relative overhead decreases**

This is why all bindings show better **relative** performance for large messages.

---

### Throughput vs Latency

**Q: Why are throughput and latency results different?**

A: They test **different aspects** of performance:

**Latency Test (REQ-REP):**
- Measures round-trip time for request-reply
- **Synchronous**: Wait for reply before next send
- **Single message in flight** at any time
- Dominated by per-call overhead

**Throughput Test (PUSH-PULL):**
- Measures sustained message rate
- **Asynchronous**: Send without waiting
- **Multiple messages in flight** (pipelining)
- **Batching** and **buffering** effects
- Dominated by data transfer rate

**Why results differ:**
- Batching amortizes fixed overhead
- Pipeline parallelism hides latency
- Buffer management becomes important
- CPU vs I/O bottlenecks shift

**Example:**
```
Node.js latency:   85μs   (slow, per-call overhead)
Node.js throughput: 860K msg/s  (better, batching helps)
```

---

## Technical Questions

### libzmq version consistency

**Q: How do you ensure all implementations use the same libzmq?**

A: We use **libzmq-native** (github.com/ulala-x/libzmq-native):
- Pre-built libzmq 4.3.5 static libraries
- Included as git submodule
- All implementations link against this **exact same binary**
- Build scripts reference `third-party/libzmq-native`

This ensures:
- No version differences
- No build flag differences
- Fair performance comparison

---

### Timer precision

**Q: How accurate are your latency measurements?**

A: We use **high-resolution timers** with nanosecond precision:

**C++:**
```cpp
std::chrono::high_resolution_clock  // Typically <10ns overhead
```

**NET:**
```csharp
System.Diagnostics.Stopwatch        // QueryPerformanceCounter, <100ns overhead
```

**Node.js:**
```javascript
process.hrtime.bigint()             // <100ns overhead
```

**Measurement error:**
- Timer overhead: < 100ns
- Measured latency: 50,000-100,000ns
- **Error rate: < 0.2%**

This is **more than sufficient** for comparing microsecond-scale differences.

---

### Why localhost only?

**Q: Why not test over a real network?**

A: **Intentional design choice** to isolate binding overhead:

**With real network:**
- Network latency: 0.1-100+ ms
- Binding overhead: 0.01-0.1 ms
- Network **dominates** results
- Can't distinguish binding performance

**With localhost:**
- Network latency: < 0.001 ms (kernel only)
- Binding overhead: 0.01-0.1 ms
- Binding overhead is **measurable**
- Fair comparison possible

**You should test your workload** on real network to validate that binding overhead matters for your use case.

---

### Socket options

**Q: Are socket options configured for maximum performance?**

A: We use **default options** intentionally:

**Defaults used:**
- High-water marks: 1000 (default)
- Buffer sizes: System default
- I/O threads: 1
- Socket options: All defaults

**Why defaults:**
- Out-of-the-box experience
- Fair comparison (no hand-tuning per language)
- Realistic for most users

**For production:**
- Tune HWM based on your latency/throughput needs
- Adjust buffers for your message sizes
- Configure I/O threads for your workload
- See [ZeroMQ Guide - Socket Options](https://zguide.zeromq.org/)

---

## Troubleshooting

### Address already in use

**Q: Error: "Address already in use" when running tests**

A: Previous test process still holds the port:

**Solution 1: Wait**
```bash
# Wait 5-10 seconds for kernel to release port
sleep 10
./run_benchmark.sh
```

**Solution 2: Check for running processes**
```bash
# Find process using port 5555
lsof -i :5555

# Kill if needed
kill <PID>
```

**Solution 3: Use different port**
```bash
# Edit run_benchmark.sh to use different ports
LAT_PORT=5557  # Instead of 5555
THR_PORT=5558  # Instead of 5556
```

**Solution 4: Set SO_REUSEADDR**
```bash
# Add to socket options (language-specific)
# C++: socket.set(zmq::sockopt::reuseaddr, 1);
# .NET: socket.SetSocketOption(ZSocketOption.REUSEADDR, 1);
```

---

### libzmq not found

**Q: Error: "libzmq.so: cannot open shared object file"**

A: libzmq-native not built or not in library path:

**Solution 1: Build libzmq-native**
```bash
cd third-party/libzmq-native
./build-scripts/linux/build.sh  # or macos/windows
cd ../..
```

**Solution 2: Check submodules**
```bash
git submodule update --init --recursive
```

**Solution 3: Set library path**
```bash
# Linux
export LD_LIBRARY_PATH=$PWD/third-party/libzmq-native/lib:$LD_LIBRARY_PATH

# macOS
export DYLD_LIBRARY_PATH=$PWD/third-party/libzmq-native/lib:$DYLD_LIBRARY_PATH
```

**Solution 4: Install system libzmq (not recommended)**
```bash
# This may use different version!
sudo apt-get install libzmq3-dev  # Ubuntu/Debian
brew install zeromq                # macOS
```

---

### Results vary between runs

**Q: Why do my results differ by 10-20% between runs?**

A: Some variance is normal due to:

**System factors:**
- CPU frequency scaling (turbo boost)
- Background processes
- OS scheduling jitter
- Thermal throttling

**Acceptable variance:**
- Latency: ±5-10%
- Throughput: ±10-15%

**Reduce variance:**
1. **Close background applications**
2. **Disable CPU frequency scaling:**
   ```bash
   # Linux
   sudo cpupower frequency-set -g performance
   ```
3. **Run multiple times and average:**
   ```bash
   for i in {1..5}; do
       ./run_benchmark.sh
       sleep 10
   done
   ```
4. **Check system load:**
   ```bash
   uptime  # Load average should be < 1
   ```

**If variance > 20%:**
- Check for thermal throttling
- Verify no other network apps running
- Ensure adequate cooling
- Consider dedicated benchmark machine

---

### Build failures

**Q: Compilation or build errors**

A: **C++ Build Issues:**

```bash
# Missing CMake
sudo apt-get install cmake

# Missing compiler
sudo apt-get install g++

# Missing libzmq headers
cd third-party/libzmq-native
./build-scripts/linux/build.sh
```

**NET Build Issues:**

```bash
# Missing .NET SDK
# Download from: https://dotnet.microsoft.com/download

# Restore packages
dotnet restore

# Clean and rebuild
dotnet clean
dotnet build -c Release
```

**Node.js Build Issues:**

```bash
# Missing Node.js
# Download from: https://nodejs.org/

# Missing build tools (Linux)
sudo apt-get install build-essential python3

# Missing build tools (macOS)
xcode-select --install

# Rebuild native addon
npm rebuild
```

---

### Permission errors

**Q: Permission denied when running scripts**

A: Scripts not executable:

**Solution:**
```bash
# Make script executable
chmod +x run_benchmark.sh
chmod +x scripts/*.sh

# Or run with bash
bash run_benchmark.sh
```

---

### Unexpectedly low performance

**Q: My results are much slower than documented**

A: Check these common issues:

**1. Debug build instead of Release:**
```bash
# C++: Verify -O3 flag
cmake .. -DCMAKE_BUILD_TYPE=Release

# .NET: Verify Release configuration
dotnet build -c Release

# Node.js: Verify NODE_ENV
export NODE_ENV=production
```

**2. Running in VM or container:**
- Virtualization adds overhead
- Shared CPU resources
- Results will be slower but **relative** comparison still valid

**3. Incorrect timer usage:**
- Verify high-resolution timer API
- Check timer placement (must wrap send/recv loop)
- Validate calculation formulas

**4. Extra work in hot path:**
- Remove debug prints
- Avoid allocations in loop
- Check for accidental serialization

---

## Contributing Questions

### Adding a new language

**Q: How do I add support for a new language?**

A: See detailed guide in [Contributing](contributing.md), but overview:

1. **Create language directory** (e.g., `python/`)
2. **Implement 4 programs:** local-lat, remote-lat, local-thr, remote-thr
3. **Create run_benchmark.sh** for automation
4. **Write README.md** with implementation details
5. **Document results** in `docs/results/your-language.md`
6. **Update comparison scripts**
7. **Submit pull request**

---

### Test pattern requirements

**Q: Can I use different test patterns?**

A: For fair comparison, you must:
- Use **REQ/REP** for latency test
- Use **PUSH/PULL** for throughput test
- Follow **exact timing methodology**
- Use **same message sizes** (64, 1500, 65536 bytes)
- Use **same iteration counts** (10K latency, 1M throughput)

If you want to test different patterns (PUB/SUB, DEALER/ROUTER):
- Add as **separate tests** in your directory
- Document in your README
- Don't include in main comparison (not apples-to-apples)

---

### Benchmark validation

**Q: How do I know if my implementation is correct?**

A: Validation checklist:

**Sanity checks:**
- [ ] Latency between 10-300 μs (localhost range)
- [ ] Throughput between 100K-10M msg/s
- [ ] Results consistent across runs (±10%)
- [ ] No errors or warnings

**Comparison checks:**
- [ ] Performance within 2-3x of C++ baseline
- [ ] Performance trends match (small messages harder)
- [ ] Large messages show better relative performance

**Technical checks:**
- [ ] Timer is high-resolution (nanosecond precision)
- [ ] Timer placement is correct (before first send, after last receive)
- [ ] Latency calculation divides by 2 (round-trip → one-way)
- [ ] Throughput excludes first message (synchronization)

---

## Still Have Questions?

**Open an issue:**
- GitHub: [zmq-binding-benchmark/issues](https://github.com/ulala-x/zmq-binding-benchmark/issues)
- Tag with `question` label

**Check resources:**
- [Methodology](methodology.md) - Testing methodology
- [Architecture](architecture.md) - Technical details
- [Contributing](contributing.md) - Implementation guide
- [ZeroMQ Guide](https://zguide.zeromq.org/) - ZeroMQ documentation

---

**Last Updated:** 2025-12-17
**Project:** ZeroMQ Binding Performance Benchmark
