# ZeroMQ C++ Benchmark (cppzmq)

C++ baseline implementation for ZeroMQ performance benchmarking using [cppzmq](https://github.com/zeromq/cppzmq) (C++ binding for libzmq).

## Overview

This benchmark suite measures:
- **Latency**: Round-trip message latency using REQ/REP pattern
- **Throughput**: Unidirectional message throughput using PUSH/PULL pattern

## Dependencies

- **CMake** 3.15 or higher
- **C++17** compatible compiler (GCC 7+, Clang 5+, MSVC 2017+)
- **libzmq** 4.3.5 (via libzmq-native submodule)
- **cppzmq** (header-only, via submodule)

## Project Structure

```
cpp/
├── CMakeLists.txt          # Build configuration
├── README.md               # This file
├── run_benchmark.sh        # Automated benchmark runner
├── third-party/
│   ├── libzmq-native/     # Native libzmq builds (submodule)
│   └── cppzmq/            # C++ bindings (submodule)
└── src/
    ├── local_lat.cpp      # Latency test server (REP)
    ├── remote_lat.cpp     # Latency test client (REQ)
    ├── local_thr.cpp      # Throughput receiver (PULL)
    └── remote_thr.cpp     # Throughput sender (PUSH)
```

## Building

### 1. Clone with submodules

If you haven't cloned the repository with `--recursive`:

```bash
git submodule update --init --recursive
```

### 2. Build libzmq-native

**Linux:**
```bash
cd third-party/libzmq-native
./build-scripts/linux/build.sh
cd ../..
```

**macOS:**
```bash
cd third-party/libzmq-native
# For Intel Mac
./build-scripts/macos/build.sh x86_64
# For Apple Silicon
./build-scripts/macos/build.sh arm64
cd ../..
```

**Windows:**
```powershell
cd third-party\libzmq-native
.\build-scripts\windows\build.ps1
cd ..\..
```

### 3. Build benchmark executables

```bash
mkdir build
cd build
cmake ..
make -j$(nproc)
cd ..
```

This creates four executables:
- `build/local_lat` - Latency test server
- `build/remote_lat` - Latency test client
- `build/local_thr` - Throughput receiver
- `build/remote_thr` - Throughput sender

## Running Tests

### Automated Benchmark

Run all tests with multiple message sizes:

```bash
./run_benchmark.sh
```

Results are saved to `../docs/results/cpp-baseline.md`.

### Manual Testing

**Latency Test:**

Terminal 1 (Server):
```bash
./build/local_lat tcp://*:5555 64 10000
```

Terminal 2 (Client):
```bash
./build/remote_lat tcp://localhost:5555 64 10000
```

**Throughput Test:**

Terminal 1 (Receiver):
```bash
./build/local_thr tcp://*:5556 64 1000000
```

Terminal 2 (Sender):
```bash
./build/remote_thr tcp://localhost:5556 64 1000000
```

## Test Parameters

| Test | Message Sizes | Count | Description |
|------|--------------|-------|-------------|
| Latency | 64B, 1500B, 65KB | 10,000 | Round-trip time ÷ 2 |
| Throughput | 64B, 1500B, 65KB | 1,000,000 | Messages per second |

## Expected Results

Typical results on modern hardware (localhost):

| Test | 64 bytes | 1500 bytes | 65536 bytes |
|------|----------|------------|-------------|
| **Latency** | ~30-50 μs | ~35-55 μs | ~100-150 μs |
| **Throughput** | 2-5 M msg/s | 1-3 M msg/s | 200-500 K msg/s |

*Results vary based on CPU, memory, and system load.*

## Implementation Details

### Optimization Flags

CMakeLists.txt uses aggressive optimization:
```cmake
-O3              # Maximum optimization
-march=native    # CPU-specific optimizations
-flto            # Link-time optimization
```

### RAII Pattern

All programs use cppzmq's RAII wrappers:
- `zmq::context_t` - Automatic context cleanup
- `zmq::socket_t` - Automatic socket closure
- `zmq::message_t` - Automatic message memory management

### Timing

- Uses `std::chrono::high_resolution_clock` for microsecond precision
- Latency: Total time ÷ (rounds × 2)
- Throughput: Messages ÷ elapsed seconds

### Socket Patterns

**Latency (REQ/REP):**
- Synchronous request-reply
- REQ sends, REP echoes back
- Measures round-trip latency

**Throughput (PUSH/PULL):**
- Asynchronous one-way flow
- PUSH sends, PULL receives
- First message triggers timing (warm-up)

## Troubleshooting

### Library Not Found (Linux)

```bash
export LD_LIBRARY_PATH=third-party/libzmq-native/dist/linux-x64:$LD_LIBRARY_PATH
```

Or use the RPATH already set in CMakeLists.txt (default).

### Library Not Found (macOS)

```bash
export DYLD_LIBRARY_PATH=third-party/libzmq-native/dist/macos-arm64:$DYLD_LIBRARY_PATH
```

### Build Errors

1. Ensure libzmq-native is built: `ls third-party/libzmq-native/dist/`
2. Check CMake output for detected platform
3. Verify C++17 compiler support

### Port Already in Use

Change ports in `run_benchmark.sh`:
```bash
LAT_PORT=5555  # Change to available port
THR_PORT=5556  # Change to available port
```

## References

- [libzmq perf tools](https://github.com/zeromq/libzmq/tree/master/perf)
- [cppzmq documentation](https://github.com/zeromq/cppzmq)
- [ZeroMQ Guide](https://zguide.zeromq.org/)

## License

MIT License - See [LICENSE](../LICENSE) for details.
