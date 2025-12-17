# Contributing Guide

**Document Version:** 1.0
**Last Updated:** 2025-12-17

Welcome! We appreciate your interest in contributing to the ZeroMQ Binding Performance Benchmark project.

## Table of Contents

- [Ways to Contribute](#ways-to-contribute)
- [Adding a New Language Implementation](#adding-a-new-language-implementation)
- [Code Standards](#code-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation Requirements](#documentation-requirements)
- [Pull Request Process](#pull-request-process)
- [Getting Help](#getting-help)

## Ways to Contribute

### New Language Implementations

The primary contribution is adding new language bindings:

- **Python** (pyzmq) - High priority
- **Java** (JeroMQ or jzmq) - High priority
- **Go** (go-zeromq or pebbe/zmq4) - Medium priority
- **Rust** (tmq or zeromq-rs) - Medium priority
- **Ruby** (ffi-rzmq) - Low priority
- **PHP** (php-zmq) - Low priority
- Other languages with ZeroMQ bindings

### Other Contributions

- **Additional test patterns**: PUB/SUB, DEALER/ROUTER
- **Transport types**: IPC, inproc comparisons
- **Multi-threading tests**: Thread-safe socket sharing
- **Security tests**: CURVE encryption overhead
- **Memory profiling**: Heap usage analysis
- **Documentation improvements**: Clarifications, examples
- **Bug fixes**: Issues with existing implementations
- **CI/CD**: Automated testing infrastructure

## Adding a New Language Implementation

### Prerequisites

Before starting:

1. **Read existing documentation:**
   - [Methodology](methodology.md) - Testing standards
   - [Architecture](architecture.md) - Technical details
   - Existing implementation READMEs (cpp, dotnet, nodejs)

2. **Verify ZeroMQ binding availability:**
   - Check for mature, maintained binding
   - Verify libzmq 4.3.5 compatibility
   - Ensure binding supports REQ/REP and PUSH/PULL patterns

3. **Set up development environment:**
   - Install language runtime
   - Install ZeroMQ binding
   - Verify libzmq-native works on your platform

### Directory Structure

Create a new directory for your language:

```
your-language/
├── local-lat.[ext]        # REP socket latency server
├── remote-lat.[ext]       # REQ socket latency client
├── local-thr.[ext]        # PULL socket throughput receiver
├── remote-thr.[ext]       # PUSH socket throughput sender
├── run_benchmark.sh       # Automated test script
├── README.md              # Language-specific documentation
├── [build files]          # Makefile, package.json, etc.
└── .gitignore             # Language-specific ignores
```

### Implementation Checklist

#### 1. Latency Test Programs

**local-lat (REP server):**

```
Required behavior:
1. Parse command-line arguments: bind_address, message_size, message_count
2. Create ZeroMQ context
3. Create REP socket
4. Bind to specified address (e.g., tcp://127.0.0.1:5555)
5. Loop for message_count times:
   a. Receive message
   b. Send same message back (echo)
6. Clean up resources
7. Exit with code 0 on success
```

**remote-lat (REQ client):**

```
Required behavior:
1. Parse command-line arguments: connect_address, message_size, message_count
2. Create ZeroMQ context
3. Create REQ socket
4. Connect to specified address
5. Allocate message buffer of message_size bytes
6. Start high-resolution timer
7. Loop for message_count times:
   a. Send message
   b. Receive reply
8. Stop timer
9. Calculate and print results:
   - Message size
   - Message count
   - Total elapsed time
   - Average latency (elapsed / count / 2)
10. Clean up resources
11. Exit with code 0 on success
```

**Critical requirements:**
- Timer must be **high-resolution** (nanosecond precision)
- Timer starts **before first send**
- Timer stops **after last receive**
- Latency calculation: `(elapsed_time / message_count) / 2`
- Use **same message size** for all messages

#### 2. Throughput Test Programs

**local-thr (PULL receiver):**

```
Required behavior:
1. Parse command-line arguments: bind_address, message_size, message_count
2. Create ZeroMQ context
3. Create PULL socket
4. Bind to specified address (e.g., tcp://127.0.0.1:5556)
5. Receive first message (synchronization point)
6. Start high-resolution timer
7. Loop for (message_count - 1) times:
   a. Receive message
8. Stop timer
9. Calculate and print results:
   - Message size
   - Message count
   - Total elapsed time
   - Throughput in messages/second
   - Throughput in megabits/second
10. Clean up resources
11. Exit with code 0 on success
```

**remote-thr (PUSH sender):**

```
Required behavior:
1. Parse command-line arguments: connect_address, message_size, message_count
2. Create ZeroMQ context
3. Create PUSH socket
4. Connect to specified address
5. Allocate message buffer of message_size bytes
6. Loop for message_count times:
   a. Send message
7. Clean up resources
8. Exit with code 0 on success
```

**Critical requirements:**
- First message is **synchronization** (excluded from timing)
- Timer starts **after first receive**
- Timer stops **after last receive**
- Throughput calculation: `(message_count - 1) / elapsed_time`
- Sender sends **as fast as possible** (no delays)

#### 3. Automation Script

Create `run_benchmark.sh` following this template:

```bash
#!/bin/bash

# Configuration
RESULTS_DIR="../docs/results"
RESULTS_FILE="${RESULTS_DIR}/your-language.md"
MESSAGE_SIZES=(64 1500 65536)
LAT_ROUNDS=10000
THR_MESSAGES=1000000

# Ports
LAT_PORT=5555
THR_PORT=5556

# Build step (if needed)
echo "Building your-language benchmarks..."
# Add your build command here

# Run tests
echo "Running benchmarks..."

# Latency tests
for size in "${MESSAGE_SIZES[@]}"; do
    ./local-lat tcp://127.0.0.1:${LAT_PORT} ${size} ${LAT_ROUNDS} &
    SERVER_PID=$!
    sleep 0.5
    ./remote-lat tcp://127.0.0.1:${LAT_PORT} ${size} ${LAT_ROUNDS}
    wait $SERVER_PID
done

# Throughput tests
for size in "${MESSAGE_SIZES[@]}"; do
    ./local-thr tcp://127.0.0.1:${THR_PORT} ${size} ${THR_MESSAGES} &
    SERVER_PID=$!
    sleep 0.5
    ./remote-thr tcp://127.0.0.1:${THR_PORT} ${size} ${THR_MESSAGES}
    wait $SERVER_PID
done

echo "Benchmarks complete!"
```

**Make it executable:**
```bash
chmod +x run_benchmark.sh
```

#### 4. Language-Specific README

Create `README.md` with these sections:

```markdown
# Your Language ZeroMQ Benchmark

## Implementation Details

- Runtime version: X.Y.Z
- ZeroMQ binding: package-name version
- libzmq version: 4.3.5 (from libzmq-native)

## Dependencies

List all dependencies and installation instructions.

## Building

Provide clear build instructions.

## Running Tests

### Individual Tests

Commands to run each test individually.

### Automated Benchmark

```bash
./run_benchmark.sh
```

## Results

Reference results file: `docs/results/your-language.md`

## Implementation Notes

- Describe any language-specific considerations
- Note any limitations or workarounds
- Explain binding architecture
```

## Code Standards

### General Principles

1. **Follow existing patterns**: Look at C++, .NET, and Node.js implementations
2. **Identical logic**: Same test flow as other implementations
3. **Clear structure**: Easy to understand and maintain
4. **Minimal dependencies**: Only ZeroMQ binding and standard library
5. **Error handling**: Proper error checking and cleanup

### Language-Specific Conventions

Follow the standard conventions for your language:

**C++:**
- C++17 standard
- RAII for resource management
- `snake_case` for variables/functions
- Error handling via exceptions

**.NET:**
- C# 12+ features
- `PascalCase` for public members
- `camelCase` for local variables
- `using` statements for cleanup

**Node.js:**
- ES2020+ async/await
- `camelCase` for all identifiers
- Promises for async operations

**Python:**
- PEP 8 style guide
- Type hints (Python 3.9+)
- Context managers for cleanup

**Java:**
- Java 17+
- `camelCase` for methods/variables
- `PascalCase` for classes
- Try-with-resources for cleanup

### Code Comments

Include comments for:

1. **High-level purpose** at file start
2. **Non-obvious implementation details**
3. **Timing measurement points** (critical!)
4. **Calculation formulas**

**Example:**
```python
# Start timer before first send operation
# This includes only send/receive overhead, not setup
start = time.perf_counter_ns()

for i in range(message_count):
    socket.send(message)
    socket.recv()

# Stop timer after last receive
end = time.perf_counter_ns()

# Calculate one-way latency (round-trip time / 2)
elapsed = (end - start) / 1_000_000_000  # Convert to seconds
latency = (elapsed / message_count) / 2
```

### Naming Conventions

**Executable names:**
- Latency server: `local-lat[.ext]`
- Latency client: `remote-lat[.ext]`
- Throughput receiver: `local-thr[.ext]`
- Throughput sender: `remote-thr[.ext]`

**Variable names (suggested):**
- Context: `context`, `ctx`
- Socket: `socket`, `sock`
- Message: `message`, `msg`, `frame`, `buffer`
- Size: `message_size`, `size`
- Count: `message_count`, `count`

## Testing Requirements

### Local Testing

Before submitting, test your implementation:

1. **Build successfully:**
   ```bash
   cd your-language
   # Run your build command
   ```

2. **Run individual tests:**
   ```bash
   # Terminal 1
   ./local-lat tcp://127.0.0.1:5555 64 10000

   # Terminal 2
   ./remote-lat tcp://127.0.0.1:5555 64 10000
   ```

3. **Run automated benchmark:**
   ```bash
   ./run_benchmark.sh
   ```

4. **Verify results:**
   - Check that `docs/results/your-language.md` is created
   - Verify latency values are reasonable (10-200 μs range)
   - Verify throughput values are reasonable (100K-10M msg/s range)

### Validation Checklist

- [ ] All four programs compile/run without errors
- [ ] Latency test completes for all message sizes
- [ ] Throughput test completes for all message sizes
- [ ] Results file is generated with proper formatting
- [ ] Results are consistent across multiple runs (±10%)
- [ ] No memory leaks (use language-specific tools)
- [ ] Clean shutdown (no errors or warnings)

### Performance Expectations

Your results should be in these ballpark ranges:

**Latency:**
- C++ baseline: 50-70 μs
- Managed languages: 50-150 μs (depending on binding quality)
- Interpreted languages: 80-300 μs

**Throughput:**
- C++ baseline: 5-10M msg/s (small), 100-200K msg/s (large)
- Managed languages: 2-8M msg/s (small), 50-150K msg/s (large)
- Interpreted languages: 500K-3M msg/s (small), 50-100K msg/s (large)

If your results are significantly outside these ranges, investigate:
- Timer precision issues
- Incorrect calculation formulas
- Extra overhead in test code
- Binding or runtime configuration problems

## Documentation Requirements

### Result Documentation

Create `docs/results/your-language.md`:

```markdown
# Your Language ZeroMQ Benchmark Results

**Date:** YYYY-MM-DD
**Environment:** OS version, architecture
**Runtime:** Your Language X.Y.Z
**Binding:** package-name version
**libzmq:** 4.3.5 (from libzmq-native)

## Test Configuration

[Standard configuration details]

## Latency Results

[Table with results for all message sizes]

## Throughput Results

[Table with results for all message sizes]

## Comparison with C++ Baseline

[Overhead analysis]

## Performance Analysis

[Discuss your results, overhead sources, strengths/weaknesses]

## Implementation Notes

[Any special considerations]
```

### Update Comparison Script

Add your language to `scripts/compare.py`:

```python
# In parse_result_file function, add pattern for your language
if "Your Language" in content:
    # Add parsing logic
```

### Update Project Documentation

Update these files:

1. **Root README.md:**
   - Add to "Implementations Tested" list
   - Update "Implementation Status" checkboxes

2. **docs/SUMMARY.md:**
   - Add your results to comparison tables
   - Update "Implementations Tested" section

## Pull Request Process

### 1. Fork and Branch

```bash
# Fork repository on GitHub
git clone https://github.com/YOUR-USERNAME/zmq-binding-benchmark.git
cd zmq-binding-benchmark

# Create feature branch
git checkout -b add-your-language-binding
```

### 2. Implement and Test

```bash
# Create your implementation
mkdir your-language
# ... implement programs ...

# Test locally
cd your-language
./run_benchmark.sh

# Verify results
cat ../docs/results/your-language.md
```

### 3. Commit Changes

```bash
# Add your files
git add your-language/
git add docs/results/your-language.md

# Commit with descriptive message
git commit -m "Add Your Language (package-name) implementation

- Implement latency and throughput tests
- Add automated benchmark script
- Document results and performance analysis
- Update comparison scripts
"
```

### 4. Submit Pull Request

1. **Push to your fork:**
   ```bash
   git push origin add-your-language-binding
   ```

2. **Create pull request on GitHub** with:

   **Title:** `Add Your Language (package-name) implementation`

   **Description:**
   ```markdown
   ## Summary
   Adds ZeroMQ benchmark implementation for Your Language using package-name binding.

   ## Implementation Details
   - Runtime: Your Language X.Y.Z
   - Binding: package-name version
   - libzmq: 4.3.5 (from libzmq-native)
   - All four test programs implemented
   - Automated benchmark script included

   ## Test Results
   - Latency (64B): XX.X μs (YY% vs C++)
   - Throughput (64B): X.XXM msg/s (YY% vs C++)
   - See docs/results/your-language.md for full results

   ## Checklist
   - [x] All tests run successfully
   - [x] Results documented
   - [x] Code follows project conventions
   - [x] README.md included
   - [x] Comparison script updated
   ```

### 5. Review Process

**We will review:**
- Code quality and adherence to standards
- Test result validity and consistency
- Documentation completeness
- Proper use of timing APIs

**You may be asked to:**
- Adjust implementation details
- Add clarifications to documentation
- Re-run tests if results seem anomalous
- Fix any issues found during review

## Getting Help

### Resources

- **Documentation:**
  - [Methodology](methodology.md) - Testing standards
  - [Architecture](architecture.md) - Technical details
  - Existing implementation READMEs

- **ZeroMQ Resources:**
  - [ZeroMQ Guide](https://zguide.zeromq.org/)
  - [libzmq API Reference](http://api.zeromq.org/)
  - Your binding's documentation

### Questions?

- **Open an issue** on GitHub with label `question`
- **Check existing implementations** for examples
- **Read ZeroMQ Guide** for pattern details

### Common Issues

**Issue:** Different latency values across runs

**Solution:** This is normal variance (±5-10%). Run multiple times and verify results are consistent within that range.

---

**Issue:** "Address already in use" error

**Solution:**
```bash
# Wait a few seconds between test runs, or use different ports
# Check if previous test process is still running:
ps aux | grep "local-lat\|local-thr"
```

---

**Issue:** Very high latency or low throughput

**Solution:**
- Verify timer precision (must be nanosecond resolution)
- Check calculation formulas match methodology
- Ensure Release/optimized build, not Debug
- Review binding documentation for performance tips

---

**Issue:** Build or linking errors

**Solution:**
- Verify libzmq is installed or accessible
- Check binding version compatibility
- Review language-specific installation docs
- Try building existing implementations first

## Thank You!

Your contribution helps the community understand ZeroMQ binding performance across languages. We appreciate your effort!

---

**Project:** ZeroMQ Binding Performance Benchmark
**Maintained by:** ulala-x
**License:** MIT
