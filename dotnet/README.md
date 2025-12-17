# .NET ZeroMQ Binding Performance Tests

This directory contains the .NET implementation of ZeroMQ performance benchmarks using [Net.Zmq](https://github.com/ulala-x/net-zmq).

## Overview

The benchmark suite measures:
- **Latency**: Round-trip time for request-reply pattern (REQ/REP sockets)
- **Throughput**: Message processing rate for push-pull pattern (PUSH/PULL sockets)

Tests are designed to be identical to the C++ baseline implementation for fair comparison.

## Dependencies

- **.NET 8.0 SDK** or later
- **Net.Zmq** (v1.0.2 or later) - automatically restored via NuGet

The Net.Zmq library is a high-performance .NET wrapper for libzmq that uses P/Invoke for native interop.

## Project Structure

```
dotnet/
├── NetZmq.PerfTests.csproj  # Project configuration
├── Program.cs               # Entry point and test routing
├── LocalLat.cs              # Latency server (REP socket)
├── RemoteLat.cs             # Latency client (REQ socket)
├── LocalThr.cs              # Throughput receiver (PULL socket)
├── RemoteThr.cs             # Throughput sender (PUSH socket)
├── run_benchmark.sh         # Automated benchmark runner
└── README.md                # This file
```

## Building

Build the project in Release mode for accurate performance measurements:

```bash
cd dotnet
dotnet build -c Release
```

## Running Tests

### Quick Start: Run All Benchmarks

Execute the automated benchmark suite:

```bash
cd dotnet
./run_benchmark.sh
```

This will:
- Build the project in Release mode
- Run latency and throughput tests for 64B, 1500B, and 65KB messages
- Save results to `docs/results/dotnet.md`
- Calculate overhead compared to C++ baseline

### Individual Tests

You can run tests individually for specific scenarios:

#### Latency Test

Terminal 1 (Server):
```bash
dotnet run -c Release -- local_lat tcp://*:5555 64 10000
```

Terminal 2 (Client):
```bash
dotnet run -c Release -- remote_lat tcp://127.0.0.1:5555 64 10000
```

#### Throughput Test

Terminal 1 (Receiver):
```bash
dotnet run -c Release -- local_thr tcp://*:5556 64 1000000
```

Terminal 2 (Sender):
```bash
dotnet run -c Release -- remote_thr tcp://127.0.0.1:5556 64 1000000
```

### Test Parameters

- `<bind_to>`: Endpoint to bind (e.g., `tcp://*:5555`)
- `<connect_to>`: Endpoint to connect (e.g., `tcp://127.0.0.1:5555`)
- `<message_size>`: Message size in bytes (e.g., 64, 1500, 65536)
- `<roundtrip_count>`: Number of roundtrips for latency test (e.g., 10000)
- `<message_count>`: Number of messages for throughput test (e.g., 1000000)

## Implementation Details

### Socket Types

- **REP/REQ**: Synchronous request-reply pattern for latency measurement
- **PULL/PUSH**: Unidirectional pipeline pattern for throughput measurement

### Timing Methodology

**Latency:**
- Uses `System.Diagnostics.Stopwatch` for high-resolution timing
- Measures total time for N roundtrips
- Calculates one-way latency: `total_time / (roundtrips * 2)`
- Includes warm-up message before timing starts

**Throughput:**
- Measures time to receive N messages
- Excludes first message (warm-up) from timing
- Calculates: `(messages - 1) / elapsed_time`

### Optimization Settings

The `.csproj` file includes optimal Release settings:

```xml
<Optimize>true</Optimize>
<TieredCompilation>true</TieredCompilation>
<TieredCompilationQuickJit>false</TieredCompilationQuickJit>
<AllowUnsafeBlocks>true</AllowUnsafeBlocks>
```

## Performance Expectations

Based on the C++ baseline, expected .NET performance:

### Latency (64B messages)
- **C++ baseline**: ~56 μs
- **Expected .NET**: ~60-70 μs (+10-20% overhead)

### Throughput (64B messages)
- **C++ baseline**: ~5.2M msg/s
- **Expected .NET**: ~4.2-4.7M msg/s (-10-20% throughput)

### Overhead Sources

1. **P/Invoke Cost**: Each ZeroMQ API call crosses the managed-native boundary
2. **Memory Marshaling**: Data must be copied between managed and native memory
3. **GC Pressure**: Managed allocations can trigger garbage collection
4. **JIT Overhead**: Runtime compilation (minimal with tiered compilation disabled)

The overhead decreases with larger messages as data transfer time dominates over marshaling cost.

## Results

After running `./run_benchmark.sh`, view detailed results:

```bash
cat ../docs/results/dotnet.md
```

The results include:
- Latency and throughput for each message size
- Comparison with C++ baseline
- Overhead analysis
- System and environment information

## Troubleshooting

### Build Errors

If you encounter build errors:

```bash
# Restore packages
dotnet restore

# Clean and rebuild
dotnet clean
dotnet build -c Release
```

### Port Already in Use

If ports 5555 or 5556 are in use, modify the ports in `run_benchmark.sh` or use different ports when running individual tests.

### Permission Denied

Make sure the benchmark script is executable:

```bash
chmod +x run_benchmark.sh
```

## Comparison with C++

The .NET implementation mirrors the C++ implementation exactly:
- Same socket types and patterns
- Same timing measurement points
- Same message sizes and iteration counts
- Same calculation formulas

This ensures a fair, apples-to-apples comparison between the C++ cppzmq binding and the .NET Net.Zmq binding.

## References

- [Net.Zmq Repository](https://github.com/ulala-x/net-zmq)
- [ZeroMQ Guide](https://zguide.zeromq.org/)
- [C++ Baseline Results](../docs/results/cpp-baseline.md)
