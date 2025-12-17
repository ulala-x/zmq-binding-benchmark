# C++ Baseline Benchmark Results (cppzmq)

**Date:** 2025-12-17 19:03:49
**System:** Linux 6.6.87.2-microsoft-standard-WSL2
**Architecture:** x86_64
**Compiler:** c++ (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0

## Test Configuration

- **Latency Rounds:** 50000
- **Throughput Messages:** 5000000
- **Message Sizes:** 64 1500 65536 bytes

## Results

### Message Size: 64 bytes

**Latency:**
- Average: 56.1268 us
- Message rate: 8908.4 msg/s

**Throughput:**
- Messages/sec: 5.2996e+06 msg/s
- Megabits/sec: 2713.4 Mb/s

### Message Size: 1500 bytes

**Latency:**
- Average: 55.5514 us
- Message rate: 9000.67 msg/s

**Throughput:**
- Messages/sec: 1.47303e+06 msg/s
- Megabits/sec: 17676.4 Mb/s

### Message Size: 65536 bytes

**Latency:**
- Average: 41.7129 us
- Message rate: 11986.7 msg/s

**Throughput:**
- Messages/sec: 93584.6 msg/s
- Megabits/sec: 49065.3 Mb/s


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
Roundtrip count: 50000

=== Latency Test Results ===
Average latency: 41.7129 us
Total elapsed time: 4171293 us
Message rate: 11986.7 msg/s
```

### Throughput Test (Last Run)
```
Listening on tcp://*:5556
Message size: 65536 bytes
Message count: 5000000
Waiting for messages...
First message received. Starting measurement...
Progress: 10% (500000/5000000)
Progress: 20% (1000000/5000000)
Progress: 30% (1500000/5000000)
Progress: 40% (2000000/5000000)
Progress: 50% (2500000/5000000)
Progress: 60% (3000000/5000000)
Progress: 70% (3500000/5000000)
Progress: 80% (4000000/5000000)
Progress: 90% (4500000/5000000)
Progress: 100% (5000000/5000000)

=== Throughput Test Results ===
Received: 5000000 messages
Message size: 65536 bytes
Total data: 312500 MB
Elapsed time: 53.4276 seconds
Throughput: 93584.6 msg/s
Throughput: 49065.3 Mb/s
```
