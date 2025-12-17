# C++ Baseline Benchmark Results (cppzmq)

**Date:** 2025-12-17 17:51:24
**System:** Linux 6.6.87.2-microsoft-standard-WSL2
**Architecture:** x86_64
**Compiler:** c++ (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0

## Test Configuration

- **Latency Rounds:** 10000
- **Throughput Messages:** 1000000
- **Message Sizes:** 64 1500 65536 bytes

## Results

### Message Size: 64 bytes

**Latency:**
- Average: 56.4056 us
- Message rate: 8864.37 msg/s

**Throughput:**
- Messages/sec: 5.18438e+06 msg/s
- Megabits/sec: 2654.4 Mb/s

### Message Size: 1500 bytes

**Latency:**
- Average: 53.8457 us
- Message rate: 9285.79 msg/s

**Throughput:**
- Messages/sec: 1.16964e+06 msg/s
- Megabits/sec: 14035.7 Mb/s

### Message Size: 65536 bytes

**Latency:**
- Average: 66.8024 us
- Message rate: 7484.76 msg/s

**Throughput:**
- Messages/sec: 111149 msg/s
- Megabits/sec: 58274.1 Mb/s


## Notes

- Latency is measured as round-trip time divided by 2 (one-way latency)
- Throughput measurement excludes the first message (warm-up)
- All tests use inproc or tcp://localhost for consistency
- Built with: `-O3 -march=native -flto`

## Raw Test Output

### Latency Test (Last Run)
```
Connected to tcp://localhost:5555
Message size: 65536 bytes
Roundtrip count: 10000

=== Latency Test Results ===
Average latency: 66.8024 us
Total elapsed time: 1336048 us
Message rate: 7484.76 msg/s
```

### Throughput Test (Last Run)
```
Listening on tcp://*:5556
Message size: 65536 bytes
Message count: 1000000
Waiting for messages...
First message received. Starting measurement...
Progress: 10% (100000/1000000)
Progress: 20% (200000/1000000)
Progress: 30% (300000/1000000)
Progress: 40% (400000/1000000)
Progress: 50% (500000/1000000)
Progress: 60% (600000/1000000)
Progress: 70% (700000/1000000)
Progress: 80% (800000/1000000)
Progress: 90% (900000/1000000)
Progress: 100% (1000000/1000000)

=== Throughput Test Results ===
Received: 1000000 messages
Message size: 65536 bytes
Total data: 62500 MB
Elapsed time: 8.99693 seconds
Throughput: 111149 msg/s
Throughput: 58274.1 Mb/s
```
