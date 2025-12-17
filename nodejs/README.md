# Node.js ZeroMQ Binding Benchmark

Performance benchmarks for the Node.js ZeroMQ binding ([zeromq.js](https://www.npmjs.com/package/zeromq)) comparing against the C++ baseline implementation.

## Overview

This directory contains Node.js implementations of ZeroMQ latency and throughput tests using the `zeromq` npm package (zeromq.js), which provides N-API bindings to libzmq.

## Implementation Details

### Library Used
- **Package**: `zeromq` (npm)
- **Version**: ^6.0.0
- **Binding Type**: N-API native bindings
- **Module System**: ES6 modules (type: "module")

### Socket Patterns

#### Latency Test (Request-Reply)
- **Server** (`local-lat.js`): REP socket - receives requests and sends replies
- **Client** (`remote-lat.js`): REQ socket - sends requests and measures round-trip time

#### Throughput Test (Push-Pull)
- **Receiver** (`local-thr.js`): PULL socket - receives stream of messages and measures throughput
- **Sender** (`remote-thr.js`): PUSH socket - sends stream of messages

## Requirements

- **Node.js**: >= 18.0.0
- **npm**: (bundled with Node.js)
- **Dependencies**: zeromq ^6.0.0

## Installation

Install Node.js dependencies:

```bash
npm install
```

## Usage

### Run All Benchmarks

Execute the complete benchmark suite (all message sizes):

```bash
./run_benchmark.sh
```

This will:
1. Install dependencies (if needed)
2. Run latency tests for 64B, 1500B, and 65KB messages
3. Run throughput tests for the same message sizes
4. Save results to `../docs/results/nodejs.md`

### Run Individual Tests

#### Latency Test

Terminal 1 (Server):
```bash
node local-lat.js tcp://*:5555 64 10000
```

Terminal 2 (Client):
```bash
node remote-lat.js tcp://127.0.0.1:5555 64 10000
```

#### Throughput Test

Terminal 1 (Receiver):
```bash
node local-thr.js tcp://*:5556 64 1000000
```

Terminal 2 (Sender):
```bash
node remote-thr.js tcp://127.0.0.1:5556 64 1000000
```

### Command Line Arguments

#### Latency Test
```
node local-lat.js <bind_to> <message_size> <roundtrip_count>
node remote-lat.js <connect_to> <message_size> <roundtrip_count>
```

- `bind_to/connect_to`: ZeroMQ endpoint (e.g., `tcp://*:5555`)
- `message_size`: Size of each message in bytes
- `roundtrip_count`: Number of round-trips to perform

#### Throughput Test
```
node local-thr.js <bind_to> <message_size> <message_count>
node remote-thr.js <connect_to> <message_size> <message_count>
```

- `bind_to/connect_to`: ZeroMQ endpoint (e.g., `tcp://*:5556`)
- `message_size`: Size of each message in bytes
- `message_count`: Total number of messages to send

## Implementation Notes

### Timing Measurement

The implementation uses `process.hrtime.bigint()` for high-resolution timing:

```javascript
const startTime = process.hrtime.bigint();
// ... perform operations ...
const endTime = process.hrtime.bigint();

const elapsedNanoseconds = endTime - startTime;
const elapsedMicroseconds = Number(elapsedNanoseconds / 1000n);
```

This provides nanosecond precision, which is then converted to microseconds for consistency with C++ and .NET implementations.

### Async/Await Pattern

All ZeroMQ operations use async/await:

```javascript
// Sending
await socket.send(buffer);

// Receiving
const [message] = await socket.receive();
```

This integrates naturally with Node.js's event-driven architecture but adds some overhead compared to synchronous operations.

### Memory Management

- Uses Node.js `Buffer` for binary data
- Buffers are managed by V8's garbage collector
- No manual memory management required

### Latency Calculation

Following the C++ convention:
```javascript
// Latency is one-way, so divide total time by (roundtrips * 2)
const latency = elapsedMicroseconds / (roundtripCount * 2);
```

### Throughput Calculation

Consistent with C++ implementation:
```javascript
// Exclude first message (warm-up) from throughput calculation
const throughput = (messageCount - 1) / elapsedSeconds;
```

## Performance Characteristics

### N-API Overhead

The zeromq.js library uses Node.js N-API (Native API) to call native libzmq:

1. **N-API Bridge**: Each ZeroMQ operation crosses the JavaScript/native boundary
2. **Promise Overhead**: Async operations create Promise objects
3. **Buffer Marshaling**: Data is copied between V8 and native memory
4. **Event Loop Integration**: Operations integrate with Node.js event loop

### Expected Performance

Compared to C++ baseline:

- **Small messages (64B)**: +20-30% latency overhead expected
  - N-API call overhead is significant relative to message size
  - Async/await Promise creation cost

- **Medium messages (1500B)**: +10-20% latency overhead expected
  - Buffer copying becomes more significant
  - Amortized async overhead

- **Large messages (65KB)**: +5-10% latency overhead expected
  - Data transfer dominates
  - Relative overhead decreases

### Optimization Opportunities

The zeromq.js library:
- Uses modern N-API for better performance than old NAN bindings
- Leverages V8's optimized Buffer implementation
- Provides zero-copy receive when possible
- Benefits from Node.js event loop efficiency

## Testing Different Message Sizes

Common test configurations:

```bash
# Small messages (protocol overhead dominant)
./run_benchmark.sh  # Runs 64B test

# Medium messages (balanced)
node remote-lat.js tcp://127.0.0.1:5555 1500 10000

# Large messages (bandwidth dominant)
node remote-lat.js tcp://127.0.0.1:5555 65536 10000
```

## Troubleshooting

### Port Already in Use

If you see binding errors:
```bash
# Check for processes using the ports
lsof -i :5555
lsof -i :5556

# Kill them if necessary
pkill -f "node local-lat"
pkill -f "node local-thr"
```

### Module Not Found

Ensure dependencies are installed:
```bash
npm install
```

### Permission Denied

Make sure the script is executable:
```bash
chmod +x run_benchmark.sh
```

## Comparison with Other Bindings

This implementation uses the same test methodology as:
- **C++ baseline** (`../cpp/`) - Direct libzmq usage
- **.NET** (`../dotnet/`) - Net.Zmq P/Invoke binding

All implementations:
- Use identical socket patterns (REQ/REP, PUSH/PULL)
- Test the same message sizes (64B, 1500B, 65KB)
- Use the same iteration counts
- Measure at the same points
- Follow the same calculation formulas

This ensures fair, apples-to-apples performance comparison across language bindings.

## Results

After running the benchmarks, detailed results are available in:
- `../docs/results/nodejs.md` - Full results with analysis

## References

- [zeromq.js GitHub](https://github.com/zeromq/zeromq.js)
- [zeromq.js npm](https://www.npmjs.com/package/zeromq)
- [ZeroMQ Guide](https://zguide.zeromq.org/)
- [Node.js N-API Documentation](https://nodejs.org/api/n-api.html)
