# ZeroMQ Binding Performance Benchmark

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-blue.svg)](https://github.com/ulala-x/zmq-binding-benchmark)
[![C++](https://img.shields.io/badge/C%2B%2B-17-00599C.svg?logo=c%2B%2B)](https://isocpp.org/)
[![.NET](https://img.shields.io/badge/.NET-8.0-512BD4.svg?logo=dotnet)](https://dotnet.microsoft.com/)
[![Node.js](https://img.shields.io/badge/Node.js-22-339933.svg?logo=node.js)](https://nodejs.org/)

Cross-language performance comparison of ZeroMQ bindings using cppzmq as baseline.

## Overview

This project measures and compares the performance overhead of different ZeroMQ language bindings:

- **C++ (cppzmq)** - Baseline reference implementation
- **.NET (Net.Zmq)** - P/Invoke overhead measurement
- **Node.js (zeromq.js)** - N-API overhead measurement
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
├── dotnet/                # .NET implementation (Phase 2 - Complete)
│   ├── LocalLat.cs        # REP socket latency server
│   ├── RemoteLat.cs       # REQ socket latency client
│   ├── LocalThr.cs        # PULL socket throughput receiver
│   ├── RemoteThr.cs       # PUSH socket throughput sender
│   ├── run_benchmark.sh   # Automated testing
│   └── README.md          # .NET documentation
├── nodejs/                # Node.js implementation (Phase 3 - Complete)
│   ├── local-lat.js       # REP socket latency server
│   ├── remote-lat.js      # REQ socket latency client
│   ├── local-thr.js       # PULL socket throughput receiver
│   ├── remote-thr.js      # PUSH socket throughput sender
│   ├── run_benchmark.sh   # Automated testing
│   └── README.md          # Node.js documentation
├── scripts/               # Automation scripts (Phase 4 - Complete)
│   ├── validate.sh        # Environment validation
│   ├── run-all.sh         # Run all benchmarks
│   ├── compare.py         # Results analysis
│   ├── plot.py            # Visualization (optional)
│   └── README.md          # Scripts documentation
├── docs/
│   ├── SUMMARY.md         # Executive summary
│   └── results/           # Benchmark results
│       ├── cpp-baseline.md
│       ├── dotnet.md
│       ├── nodejs.md
│       ├── analysis.md    # Detailed comparison
│       └── benchmark_data.json
└── README.md              # This file
```

## Quick Start

### Automated Full Pipeline (Recommended)

```bash
# Clone with submodules
git clone --recursive https://github.com/ulala-x/zmq-binding-benchmark.git
cd zmq-binding-benchmark

# Validate environment
./scripts/validate.sh

# Run all benchmarks and generate analysis
./scripts/run-all.sh
```

This will:
1. Build and run C++ benchmarks
2. Build and run .NET benchmarks
3. Run Node.js benchmarks
4. Generate comparative analysis
5. Create visualization plots (if matplotlib available)

Results will be in `docs/results/` including:
- `analysis.md` - Detailed comparative analysis
- `benchmark_data.json` - Raw data for further analysis
- Individual result files for each language

### Manual Per-Language Testing

#### C++ Baseline (Phase 1)

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

### .NET Implementation (Phase 2)

```bash
cd dotnet

# Install dependencies
dotnet restore

# Run automated benchmark
./run_benchmark.sh
```

Results will be saved to `docs/results/dotnet.md`.

### Node.js Implementation (Phase 3)

```bash
cd nodejs

# Install dependencies
npm install

# Run automated benchmark
./run_benchmark.sh
```

Results will be saved to `docs/results/nodejs.md`.

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

### Performance Comparison (Linux x64, WSL2)

**Test Environment:**
- System: Linux 6.6.87.2-microsoft-standard-WSL2
- C++: GCC 13.3.0, -O3 -march=native -flto
- .NET: .NET 8.0.122, Release build
- Node.js: v22.19.0, default settings

#### Latency Results (lower is better)

| Message Size | C++ Baseline | .NET (Net.Zmq) | Node.js (zeromq.js) |
|--------------|--------------|----------------|---------------------|
| 64 bytes     | 56.4 μs      | 51.1 μs (**9.3% faster**) | 85.7 μs (+52%) |
| 1500 bytes   | 53.8 μs      | 51.8 μs (**3.9% faster**) | 90.9 μs (+69%) |
| 65536 bytes  | 66.8 μs      | 71.2 μs (+6.6%) | 110.7 μs (+66%) |

#### Throughput Results (higher is better)

| Message Size | C++ Baseline | .NET (Net.Zmq) | Node.js (zeromq.js) |
|--------------|--------------|----------------|---------------------|
| 64 bytes     | 5.18M msg/s  | 4.91M msg/s (-5.3%) | 0.86M msg/s (-83%) |
| 1500 bytes   | 1.17M msg/s  | 1.34M msg/s (**+14.3% faster**) | 0.61M msg/s (-48%) |
| 65536 bytes  | 111K msg/s   | 76K msg/s (-32%) | 96K msg/s (-13%) |

### Key Findings

**🎯 .NET Performance:** Surprisingly **outperforms** C++ for small/medium message latency and medium message throughput! This demonstrates excellent P/Invoke optimization in Net.Zmq.

**📊 Node.js Performance:** Shows expected overhead from N-API bridging and async/await pattern. Performance degradation is more pronounced for small messages due to fixed per-call overhead.

**💡 Message Size Impact:**
- Small messages: Overhead dominated by call/marshaling costs
- Medium messages: Balanced performance
- Large messages: Data transfer dominates, reducing relative overhead

See detailed analysis in:
- [docs/SUMMARY.md](docs/SUMMARY.md) - Executive summary and overview
- [docs/results/analysis.md](docs/results/analysis.md) - Detailed technical comparison
- [docs/results/cpp-baseline.md](docs/results/cpp-baseline.md) - C++ baseline results
- [docs/results/dotnet.md](docs/results/dotnet.md) - .NET results with comparison
- [docs/results/nodejs.md](docs/results/nodejs.md) - Node.js results with comparison

## Documentation

- **[Methodology](docs/methodology.md)** - Testing methodology and fairness principles
- **[Architecture](docs/architecture.md)** - Technical architecture and binding comparison
- **[Contributing](docs/contributing.md)** - Guide for adding new language implementations
- **[FAQ](docs/faq.md)** - Common questions and troubleshooting
- **[Summary](docs/SUMMARY.md)** - Executive summary and key findings
- **[Detailed Analysis](docs/results/analysis.md)** - Comprehensive performance analysis

## Implementation Status

- [x] **Phase 1:** C++ baseline (cppzmq)
- [x] **Phase 2:** .NET (Net.Zmq)
- [x] **Phase 3:** Node.js (zeromq.js)
- [x] **Phase 4:** Automation and analysis scripts
- [x] **Phase 5:** Documentation and methodology
- [ ] **Phase 6:** Python (pyzmq) - Planned
- [ ] **Phase 7:** JVM (JeroMQ) - Planned

## Fairness Principles

1. **Same libzmq version** (4.3.5) for all languages
2. **Same test patterns** (identical message flow)
3. **Same measurement points** (timer start/stop)
4. **Release builds** with maximum optimizations
5. **Local transport** (tcp://localhost) for consistency

## Dependencies

- [libzmq-native](https://github.com/ulala-x/libzmq-native) - Pre-built libzmq 4.3.5 with libsodium
- [cppzmq](https://github.com/zeromq/cppzmq) - Modern C++ bindings

## Future Plans

### Upcoming Language Implementations

- **Python (pyzmq)** - Python binding performance analysis
- **Java (JeroMQ)** - Pure Java implementation comparison
- **Go (go-zeromq)** - Native Go implementation
- **Rust (tmq/zeromq-rs)** - Native Rust implementation

### Planned Enhancements

- **Additional Transport Types**: IPC, inproc comparison
- **Socket Patterns**: PUB/SUB, DEALER/ROUTER, ROUTER/DEALER
- **Multi-threading**: Thread-safe socket sharing patterns
- **Security**: CURVE encryption overhead measurement
- **Memory Profiling**: Heap usage and allocation patterns
- **CI/CD Integration**: Automated regression testing
- **Cross-Platform**: macOS and Windows native testing

### Contributions Welcome

We welcome contributions for:
- New language bindings
- Additional test patterns
- Performance improvements
- Documentation enhancements
- Bug fixes and issue reports

See [Contributing Guide](docs/contributing.md) for details on adding new implementations.

## Contributing

Contributions are welcome! Please see:
- [Contributing Guide](docs/contributing.md) - Detailed contribution guidelines
- [Methodology](docs/methodology.md) - Testing standards and requirements
- Individual language directories for specific implementation details

### Quick Contribution Guide

1. **Fork** the repository
2. **Implement** your language binding following existing patterns
3. **Test** locally using `./scripts/validate.sh`
4. **Document** results in `docs/results/your-language.md`
5. **Submit** a pull request with detailed description

## License

MIT License - See [LICENSE](LICENSE) for details.

## References

- [ZeroMQ Guide](https://zguide.zeromq.org/)
- [libzmq Performance Tests](https://github.com/zeromq/libzmq/tree/master/perf)
- [libzmq Documentation](http://api.zeromq.org/)
