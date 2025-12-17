# Architecture Overview

**Document Version:** 1.0
**Last Updated:** 2025-12-17

## Table of Contents

- [System Architecture](#system-architecture)
- [Binding Layer Comparison](#binding-layer-comparison)
- [Memory Management](#memory-management)
- [Performance Characteristics](#performance-characteristics)
- [Socket Pattern Implementation](#socket-pattern-implementation)

## System Architecture

### High-Level Stack

All language bindings share the same underlying architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                       │
│  (C++ / .NET / Node.js / Python / JVM Application Code)     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Language Binding Layer                   │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   cppzmq     │  │   Net.Zmq    │  │  zeromq.js   │     │
│  │ (Header-Only)│  │  (P/Invoke)  │  │   (N-API)    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  libzmq Native Library                      │
│              (Version 4.3.5 - Shared Core)                  │
│                                                             │
│  • Socket Types (REQ/REP, PUSH/PULL, PUB/SUB, etc.)        │
│  • Message Queuing and Routing                             │
│  • Transport Layer (TCP, IPC, inproc)                      │
│  • Threading and I/O Model                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                Operating System Layer                       │
│    (Kernel Networking Stack, TCP/IP, Sockets API)          │
└─────────────────────────────────────────────────────────────┘
```

### Key Insight

**All performance differences originate in the Binding Layer**, since:
- Same libzmq native library (4.3.5)
- Same operating system
- Same network transport (TCP localhost)
- Same test patterns and message sizes

## Binding Layer Comparison

### C++ (cppzmq)

**Architecture:**
```
┌─────────────────────────────────────────────────┐
│           Application Code (C++)                │
│      context, socket, message objects           │
└─────────────────────────────────────────────────┘
                    │
                    │ (Direct inline calls)
                    ▼
┌─────────────────────────────────────────────────┐
│              cppzmq Headers                     │
│   • Header-only template library                │
│   • RAII wrappers (zmq::context_t, etc.)        │
│   • Zero runtime overhead                       │
│   • Direct function calls to libzmq             │
└─────────────────────────────────────────────────┘
                    │
                    │ (Function call)
                    ▼
┌─────────────────────────────────────────────────┐
│              libzmq C API                       │
│   zmq_ctx_new(), zmq_socket(), zmq_send()       │
└─────────────────────────────────────────────────┘
```

**Characteristics:**

| Aspect | Details |
|--------|---------|
| **Binding Type** | Header-only template library |
| **Call Overhead** | Zero (inlined by compiler) |
| **Memory Management** | RAII (automatic cleanup) |
| **Type Safety** | Compile-time (C++ strong typing) |
| **Error Handling** | Exceptions (errno → exception) |
| **Zero-Copy** | Full support (direct pointer access) |
| **Build Complexity** | CMake + header includes |

**Advantages:**
- **Zero overhead abstraction** - Compiler inlines all calls
- **RAII safety** - Automatic resource cleanup
- **Direct libzmq access** - No marshaling layer
- **Performance baseline** - As fast as possible

**Code Example:**
```cpp
zmq::context_t ctx(1);
zmq::socket_t socket(ctx, zmq::socket_type::rep);
socket.bind("tcp://127.0.0.1:5555");

zmq::message_t msg;
socket.recv(msg);           // Direct call to zmq_msg_recv
socket.send(msg, zmq::send_flags::none);  // Direct call to zmq_msg_send
```

### .NET (Net.Zmq)

**Architecture:**
```
┌─────────────────────────────────────────────────┐
│         Application Code (C# / .NET)            │
│       ZContext, ZSocket, ZMessage objects       │
└─────────────────────────────────────────────────┘
                    │
                    │ (Managed method calls)
                    ▼
┌─────────────────────────────────────────────────┐
│              Net.Zmq Binding                    │
│   • Managed C# wrapper classes                  │
│   • Span<T> for zero-copy scenarios             │
│   • IDisposable pattern for cleanup             │
│   • P/Invoke declarations                       │
└─────────────────────────────────────────────────┘
                    │
                    │ (P/Invoke transition)
                    │ (~10-20ns per call)
                    ▼
┌─────────────────────────────────────────────────┐
│              libzmq C API                       │
│   zmq_ctx_new(), zmq_socket(), zmq_send()       │
└─────────────────────────────────────────────────┘
```

**Characteristics:**

| Aspect | Details |
|--------|---------|
| **Binding Type** | P/Invoke with managed wrappers |
| **Call Overhead** | ~10-20ns per P/Invoke transition |
| **Memory Management** | GC + IDisposable pattern |
| **Type Safety** | Runtime (CLR type checking) |
| **Error Handling** | Exceptions (errno → .NET Exception) |
| **Zero-Copy** | Partial (Span<T> for byte arrays) |
| **Build Complexity** | NuGet package restore |

**P/Invoke Mechanics:**

```csharp
// Managed side (C#)
public class ZSocket : IDisposable
{
    private IntPtr socketPtr;

    public void Send(byte[] buffer, int size)
    {
        // Transition to native code (P/Invoke)
        int rc = LibZmq.zmq_send(socketPtr, buffer, size, flags);
        // Transition back to managed code
        if (rc < 0) throw new ZException();
    }
}

// P/Invoke declaration
[DllImport("libzmq")]
private static extern int zmq_send(IntPtr socket, byte[] buf, int len, int flags);
```

**Advantages:**
- **Excellent P/Invoke optimization** - Modern .NET runtime is highly optimized
- **Span<T> support** - Zero-copy for many scenarios
- **Managed safety** - GC handles memory management
- **JIT compilation** - Can sometimes produce better code than static compilation

**Performance Surprises:**
- **Outperforms C++ for small messages** - Likely due to JIT optimization
- **Competitive for medium messages** - P/Invoke overhead is minimal
- **Shows overhead for large messages** - Memory pinning and marshaling costs

**Code Example:**
```csharp
using (var context = new ZContext())
using (var socket = new ZSocket(context, ZSocketType.REP))
{
    socket.Bind("tcp://127.0.0.1:5555");

    ZFrame frame = socket.ReceiveFrame();  // P/Invoke to zmq_msg_recv
    socket.Send(frame);                    // P/Invoke to zmq_msg_send
}  // IDisposable cleanup
```

### Node.js (zeromq.js)

**Architecture:**
```
┌─────────────────────────────────────────────────┐
│         Application Code (JavaScript)           │
│       async/await, promises, Buffer             │
└─────────────────────────────────────────────────┘
                    │
                    │ (JS function call)
                    ▼
┌─────────────────────────────────────────────────┐
│              zeromq.js Binding                  │
│   • N-API native addon                          │
│   • Promise-based API                           │
│   • Node.js Buffer integration                  │
│   • Event loop integration                      │
└─────────────────────────────────────────────────┘
                    │
                    │ (N-API bridge crossing)
                    │ (~30-50μs per call)
                    ▼
┌─────────────────────────────────────────────────┐
│          N-API Native Bridge                    │
│   • V8 value conversions                        │
│   • Handle scope management                     │
│   • Promise creation/resolution                 │
│   • GC coordination                             │
└─────────────────────────────────────────────────┘
                    │
                    │ (C++ call)
                    ▼
┌─────────────────────────────────────────────────┐
│              libzmq C++ API                     │
│   zmq_ctx_new(), zmq_socket(), zmq_send()       │
└─────────────────────────────────────────────────┘
```

**Characteristics:**

| Aspect | Details |
|--------|---------|
| **Binding Type** | N-API native addon |
| **Call Overhead** | ~30-50μs per call (bridge + promise) |
| **Memory Management** | V8 GC + native handle management |
| **Type Safety** | Runtime (JavaScript dynamic typing) |
| **Error Handling** | Promise rejection |
| **Zero-Copy** | Partial (Node.js Buffer) |
| **Build Complexity** | npm install (native compilation) |

**N-API Bridge Overhead:**

```javascript
// JavaScript side
async function sendMessage(socket, data) {
    // Async call crosses N-API bridge
    await socket.send(data);
    // Promise resolution + microtask queue
}
```

**Why N-API is slower:**

1. **Bridge Crossing**: JS → C++ requires V8 value conversions
2. **Promise Creation**: Each async operation creates a Promise object
3. **Microtask Queue**: Promise resolution adds event loop overhead
4. **GC Pressure**: More object allocations from async pattern
5. **Handle Management**: N-API requires careful handle scope management

**Advantages:**
- **Native async/await API** - Natural fit for Node.js
- **Modern N-API** - Better than old NAN bindings
- **Event loop integration** - Fits Node.js architecture
- **Developer productivity** - Clean, easy-to-use API

**Code Example:**
```javascript
const zmq = require("zeromq");

async function run() {
    const socket = new zmq.Reply();
    await socket.bind("tcp://127.0.0.1:5555");

    for await (const [msg] of socket) {  // N-API bridge crossing
        await socket.send(msg);          // N-API bridge crossing + Promise
    }
}
```

## Memory Management

### C++ (Manual + RAII)

```cpp
// Stack allocation (fastest)
zmq::message_t msg(64);  // RAII object on stack

// Automatic cleanup on scope exit
{
    zmq::socket_t socket(ctx, zmq::socket_type::rep);
    // socket automatically closed when leaving scope
}
```

**Characteristics:**
- Deterministic destruction (RAII)
- No garbage collection overhead
- Manual control over memory layout
- Zero-copy possible with careful pointer management

### .NET (Garbage Collection)

```csharp
// Managed heap allocation
byte[] buffer = new byte[64];  // GC-managed

// Span<T> for stack allocation (zero-copy)
Span<byte> span = stackalloc byte[64];

// IDisposable for deterministic cleanup
using (var socket = new ZSocket(context, ZSocketType.REP))
{
    // socket.Dispose() called automatically
}
```

**Characteristics:**
- Generational garbage collection
- IDisposable pattern for deterministic cleanup
- Span<T> enables zero-copy scenarios
- GC pressure minimized with Span<T>

**GC Impact:**
- Small messages: Minimal GC pressure
- Large messages: More allocations, but amortized
- P/Invoke pinning overhead for large buffers

### Node.js (V8 Garbage Collection)

```javascript
// V8 heap allocation
const buffer = Buffer.alloc(64);  // V8-managed

// Native handle management
const socket = new zmq.Reply();  // N-API handle
// Must explicitly close or wait for GC
await socket.close();
```

**Characteristics:**
- V8 garbage collector (generational)
- Native handles require explicit cleanup
- Promise allocations for async operations
- Higher memory overhead from async pattern

**GC Impact:**
- Frequent allocations from promises
- Native handles add finalizer overhead
- Buffer management by V8
- Async pattern increases object count

## Performance Characteristics

### Overhead Sources

| Source | C++ | .NET | Node.js |
|--------|-----|------|---------|
| **Binding Call** | 0ns | 10-20ns | 30,000-50,000ns |
| **Memory Marshaling** | 0 | Small | Moderate |
| **Promise Creation** | N/A | N/A | ~5,000ns |
| **GC Overhead** | 0 | Low | Moderate |
| **Type Conversion** | 0 | Minimal | Significant |
| **Total Overhead** | ~0ns | ~100-500ns | ~35,000-55,000ns |

### Message Size Impact

#### Small Messages (64 bytes)

**Overhead Breakdown:**

```
C++:     Call: 0ns    + Data: 50ns   = 50ns total
.NET:    Call: 15ns   + Data: 50ns   = 65ns total   (30% overhead)
Node.js: Call: 35,000ns + Data: 50ns = 35,050ns total (70,000% overhead!)
```

**Fixed overhead dominates** for small messages.

#### Medium Messages (1500 bytes)

**Overhead Breakdown:**

```
C++:     Call: 0ns    + Data: 500ns  = 500ns total
.NET:    Call: 15ns   + Data: 500ns  = 515ns total  (3% overhead)
Node.js: Call: 35,000ns + Data: 500ns = 35,500ns total (7,000% overhead)
```

**Balanced between fixed and variable overhead.**

#### Large Messages (65536 bytes)

**Overhead Breakdown:**

```
C++:     Call: 0ns    + Data: 20,000ns = 20,000ns total
.NET:    Call: 15ns   + Data: 25,000ns = 25,015ns total (25% overhead)
Node.js: Call: 35,000ns + Data: 22,000ns = 57,000ns total (185% overhead)
```

**Data transfer dominates, relative overhead decreases.**

### Throughput Characteristics

```
                Small (64B)    Medium (1500B)   Large (64KB)
                ───────────────────────────────────────────────
C++             ███████████    ████████         ███
.NET            ██████████     █████████        ██
Node.js         ██             ████             ███

Legend: █ = Relative throughput (longer is better)
```

**Key Observations:**
- C++ excels at small message throughput
- .NET competitive across all sizes
- Node.js better for large messages (overhead amortization)

## Socket Pattern Implementation

### REQ-REP Pattern (Latency Test)

**Message Flow:**
```
┌──────────┐                           ┌──────────┐
│   REQ    │ ───────── Request ──────> │   REP    │
│ (Client) │                           │ (Server) │
│          │ <──────── Reply ───────── │          │
└──────────┘                           └──────────┘
```

**Implementation Comparison:**

```cpp
// C++ - Synchronous blocking
zmq::socket_t req(ctx, zmq::socket_type::req);
req.connect("tcp://127.0.0.1:5555");

auto start = std::chrono::high_resolution_clock::now();
for (int i = 0; i < 10000; i++) {
    req.send(zmq::buffer(msg), zmq::send_flags::none);
    zmq::message_t reply;
    req.recv(reply);
}
auto elapsed = std::chrono::high_resolution_clock::now() - start;
```

```csharp
// .NET - Synchronous blocking
using var req = new ZSocket(context, ZSocketType.REQ);
req.Connect("tcp://127.0.0.1:5555");

var sw = Stopwatch.StartNew();
for (int i = 0; i < 10000; i++) {
    req.Send(new ZFrame(msg));
    var reply = req.ReceiveFrame();
}
sw.Stop();
```

```javascript
// Node.js - Async/await
const req = new zmq.Request();
await req.connect("tcp://127.0.0.1:5555");

const start = process.hrtime.bigint();
for (let i = 0; i < 10000; i++) {
    await req.send(msg);
    await req.receive();
}
const elapsed = process.hrtime.bigint() - start;
```

**Performance Impact:**
- **C++**: Direct blocking calls, minimal overhead
- **.NET**: P/Invoke per send/receive, still fast
- **Node.js**: Promise creation/resolution per call, significant overhead

### PUSH-PULL Pattern (Throughput Test)

**Message Flow:**
```
┌──────────┐                           ┌──────────┐
│   PUSH   │ ──────> Messages ──────> │   PULL   │
│ (Sender) │         (Stream)         │(Receiver)│
└──────────┘                           └──────────┘
```

**Performance Characteristics:**
- **Unidirectional**: No reply messages
- **High throughput**: Saturates connection
- **Backpressure**: High-water marks control flow

**Binding Impact:**
- C++: Maximum throughput, zero overhead
- .NET: Competitive, P/Invoke amortized over high volume
- Node.js: Async overhead less pronounced (batch sending)

## Build System Comparison

### C++ (CMake)

```cmake
find_package(cppzmq REQUIRED)
add_executable(remote-lat remote-lat.cpp)
target_link_libraries(remote-lat cppzmq)
```

**Complexity:** Moderate (CMake, find_package, linking)
**Dependencies:** System libzmq or bundled static library

### .NET (MSBuild)

```xml
<PackageReference Include="Net.Zmq" Version="1.0.0" />
```

**Complexity:** Low (NuGet package manager)
**Dependencies:** NuGet package includes native libraries

### Node.js (npm)

```json
"dependencies": {
  "zeromq": "^6.0.0"
}
```

**Complexity:** Low (npm install)
**Dependencies:** npm compiles native addon automatically

## Recommendations by Use Case

### Maximum Performance (Sub-10μs latency)

**Choose:** C++ (cppzmq)
- Zero binding overhead
- Direct native access
- Full control over memory

### Enterprise Applications (Strong typing, productivity)

**Choose:** .NET (Net.Zmq)
- Excellent performance (often matches C++)
- Type safety and modern language features
- Rich ecosystem integration

### Microservices / Web (I/O-bound, async patterns)

**Choose:** Node.js (zeromq.js)
- Natural async/await pattern
- Event loop integration
- JavaScript ecosystem
- Acceptable latency (<1ms)

## Architectural Lessons

### 1. Binding Quality Matters More Than Language

Net.Zmq proves that a well-designed binding can equal or exceed native performance.

### 2. Fixed Overhead vs Variable Overhead

- **Fixed**: Binding call cost (impacts small messages)
- **Variable**: Memory marshaling (scales with message size)

### 3. Async Pattern Has Cost

Node.js demonstrates that async/await convenience comes with measurable overhead.

### 4. Modern Runtimes Are Fast

.NET JIT and V8 produce excellent machine code, sometimes better than static compilation.

### 5. Zero-Copy is Critical

Span<T> in .NET and Buffer in Node.js enable zero-copy, reducing overhead significantly.

## References

- [cppzmq Documentation](https://github.com/zeromq/cppzmq)
- [Net.Zmq Source](https://github.com/ulala-x/net-zmq)
- [zeromq.js Documentation](https://github.com/zeromq/zeromq.js)
- [.NET P/Invoke Performance](https://learn.microsoft.com/en-us/dotnet/standard/native-interop/pinvoke)
- [Node.js N-API Documentation](https://nodejs.org/api/n-api.html)

---

**Maintained by:** ZeroMQ Binding Benchmark Project
**Last Review:** 2025-12-17
