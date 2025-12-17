# ZeroMQ Binding Performance Benchmark

Cross-language performance comparison of ZeroMQ bindings using cppzmq as baseline.

## Overview

This project measures and compares the performance overhead of different ZeroMQ language bindings:

- **C++ (cppzmq)** - Baseline reference implementation
- **.NET (net-zmq)** - P/Invoke overhead measurement (planned)
- **Node.js (zeromq.js)** - N-API overhead measurement (planned)
- **JVM (jvm-zmq)** - Future addition

All implementations use the same native libzmq library (4.3.5) from [libzmq-native](https://github.com/ulala-x/libzmq-native).

## Project Structure

```
zmq-binding-benchmark/
├── cpp/                    # C++ baseline (Phase 1 - Complete)
│   ├── src/               # Test programs
│   ├── CMakeLists.txt     # Build configuration
│   ├── run_benchmark.sh   # Automated testing
│   └── README.md          # C++ documentation
├── dotnet/                # .NET implementation (Phase 2 - Planned)
├── nodejs/                # Node.js implementation (Phase 3 - Planned)
├── docs/
│   └── results/           # Benchmark results
│       └── cpp-baseline.md
└── README.md              # This file
```

## Quick Start

### C++ Baseline (Phase 1)

```bash
# Clone with submodules
git clone --recursive https://github.com/ulala-x/zmq-binding-benchmark.git
cd zmq-binding-benchmark/cpp

# Build libzmq-native (Linux)
cd third-party/libzmq-native
./build-scripts/linux/build.sh
cd ../..

# Build benchmark executables
mkdir build && cd build
cmake ..
make -j$(nproc)
cd ..

# Run automated benchmark
./run_benchmark.sh
```

Results will be saved to `docs/results/cpp-baseline.md`.

## Test Patterns

### Latency Test
- **Pattern:** REQ/REP (request-reply)
- **Measurement:** Round-trip time ÷ 2
- **Rounds:** 10,000

### Throughput Test
- **Pattern:** PUSH/PULL (unidirectional)
- **Measurement:** Messages per second
- **Messages:** 1,000,000

### Message Sizes
- Small: 64 bytes
- Medium: 1500 bytes (typical MTU)
- Large: 65536 bytes (64 KB)

## Current Results

### C++ Baseline (Linux x64, WSL2)

| Test | 64B | 1500B | 65KB |
|------|-----|-------|------|
| **Latency** | 56.4 μs | 53.8 μs | 66.8 μs |
| **Throughput** | 5.18M msg/s | 1.17M msg/s | 111K msg/s |
| **Bandwidth** | 2.65 Gb/s | 14.0 Gb/s | 58.3 Gb/s |

*Built with: GCC 13.3.0, -O3 -march=native -flto*

See [cpp/README.md](cpp/README.md) for detailed results and [docs/results/cpp-baseline.md](docs/results/cpp-baseline.md) for raw output.

## Implementation Status

- [x] **Phase 1:** C++ baseline (cppzmq)
- [ ] **Phase 2:** .NET (net-zmq)
- [ ] **Phase 3:** Node.js (zeromq.js)
- [ ] **Phase 4:** Automation and analysis
- [ ] **Phase 5:** Documentation

## Fairness Principles

1. **Same libzmq version** (4.3.5) for all languages
2. **Same test patterns** (identical message flow)
3. **Same measurement points** (timer start/stop)
4. **Release builds** with maximum optimizations
5. **Local transport** (tcp://localhost) for consistency

## Dependencies

- [libzmq-native](https://github.com/ulala-x/libzmq-native) - Pre-built libzmq 4.3.5 with libsodium
- [cppzmq](https://github.com/zeromq/cppzmq) - Modern C++ bindings

## Contributing

Contributions are welcome! Please see individual language directories for specific implementation details.

## License

MIT License - See [LICENSE](LICENSE) for details.

## References

- [ZeroMQ Guide](https://zguide.zeromq.org/)
- [libzmq Performance Tests](https://github.com/zeromq/libzmq/tree/master/perf)
- [libzmq Documentation](http://api.zeromq.org/)
