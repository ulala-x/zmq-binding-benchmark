#!/bin/bash

# ZeroMQ .NET Binding Performance Benchmark
# Runs latency and throughput tests and saves results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_ROOT/docs/results"
RESULTS_FILE="$RESULTS_DIR/dotnet.md"

# Test parameters
LAT_ROUNDS=10000
THR_MESSAGES=1000000
MESSAGE_SIZES=(64 1500 65536)

# Ports
LAT_PORT=5555
THR_PORT=5556

echo "=========================================="
echo "  ZeroMQ .NET Binding Performance Test"
echo "=========================================="
echo

# Check if dotnet is available
if ! command -v dotnet &> /dev/null; then
    echo "Error: dotnet is not installed or not in PATH"
    exit 1
fi

# Build the project
echo "Building project..."
cd "$SCRIPT_DIR"
dotnet build -c Release > /dev/null 2>&1
echo "Build complete."
echo

# Create results directory
mkdir -p "$RESULTS_DIR"

# Start results file
cat > "$RESULTS_FILE" << EOF
# .NET Binding Benchmark Results (Net.Zmq)

**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**System:** $(uname -s) $(uname -r)
**Architecture:** $(uname -m)
**.NET Version:** $(dotnet --version)

## Test Configuration

- **Latency Rounds:** $LAT_ROUNDS
- **Throughput Messages:** $THR_MESSAGES
- **Message Sizes:** ${MESSAGE_SIZES[@]} bytes

## Results

EOF

# Run benchmarks for each message size
for SIZE in "${MESSAGE_SIZES[@]}"; do
    echo "=========================================="
    echo "Testing with message size: $SIZE bytes"
    echo "=========================================="
    echo

    # Latency Test
    echo "Running latency test..."

    # Start local_lat in background
    dotnet run -c Release -- local_lat "tcp://*:$LAT_PORT" $SIZE $LAT_ROUNDS > /tmp/dotnet_local_lat.log 2>&1 &
    LOCAL_LAT_PID=$!

    # Wait for server to start
    sleep 1

    # Run remote_lat
    LAT_OUTPUT=$(dotnet run -c Release -- remote_lat "tcp://127.0.0.1:$LAT_PORT" $SIZE $LAT_ROUNDS 2>&1)
    LAT_EXIT_CODE=$?

    # Wait for local_lat to finish
    wait $LOCAL_LAT_PID

    if [ $LAT_EXIT_CODE -eq 0 ]; then
        echo "Latency test complete."

        # Parse results
        AVG_LATENCY=$(echo "$LAT_OUTPUT" | grep "Average latency:" | awk '{print $3}')
        MSG_RATE=$(echo "$LAT_OUTPUT" | grep "Message rate:" | awk '{print $3}')

        echo "  Average latency: $AVG_LATENCY us"
        echo "  Message rate: $MSG_RATE msg/s"
    else
        echo "Error: Latency test failed"
        echo "$LAT_OUTPUT"
        exit 1
    fi

    echo

    # Throughput Test
    echo "Running throughput test..."

    # Start local_thr in background
    dotnet run -c Release -- local_thr "tcp://*:$THR_PORT" $SIZE $THR_MESSAGES > /tmp/dotnet_local_thr.log 2>&1 &
    LOCAL_THR_PID=$!

    # Wait for server to start
    sleep 1

    # Run remote_thr
    dotnet run -c Release -- remote_thr "tcp://127.0.0.1:$THR_PORT" $SIZE $THR_MESSAGES > /dev/null 2>&1 &
    REMOTE_THR_PID=$!

    # Wait for both to complete
    wait $REMOTE_THR_PID
    wait $LOCAL_THR_PID
    THR_EXIT_CODE=$?

    if [ $THR_EXIT_CODE -eq 0 ]; then
        echo "Throughput test complete."

        # Read local_thr output
        THR_OUTPUT=$(cat /tmp/dotnet_local_thr.log)

        # Parse results
        THR_MSG_SEC=$(echo "$THR_OUTPUT" | grep "Throughput:" | grep "msg/s" | awk '{print $2}')
        THR_MBITS=$(echo "$THR_OUTPUT" | grep "Throughput:" | grep "Mb/s" | awk '{print $2}')

        echo "  Throughput: $THR_MSG_SEC msg/s"
        echo "  Throughput: $THR_MBITS Mb/s"
    else
        echo "Error: Throughput test failed"
        exit 1
    fi

    echo

    # Write results to file
    cat >> "$RESULTS_FILE" << EOF
### Message Size: $SIZE bytes

**Latency:**
- Average: $AVG_LATENCY us
- Message rate: $MSG_RATE msg/s

**Throughput:**
- Messages/sec: $THR_MSG_SEC msg/s
- Megabits/sec: $THR_MBITS Mb/s

EOF
done

# Add comparison section
cat >> "$RESULTS_FILE" << 'EOF'

## Comparison with C++ Baseline

EOF

# Read C++ baseline results if available
CPP_BASELINE="$RESULTS_DIR/cpp-baseline.md"
if [ -f "$CPP_BASELINE" ]; then
    echo "Calculating overhead vs C++ baseline..."

    # Extract C++ results
    CPP_LAT_64=$(grep -A 2 "### Message Size: 64 bytes" "$CPP_BASELINE" | grep "Average:" | awk '{print $3}')
    CPP_THR_64=$(grep -A 5 "### Message Size: 64 bytes" "$CPP_BASELINE" | grep "Messages/sec:" | awk '{print $2}')

    # Extract .NET results
    NET_LAT_64=$(grep -A 2 "### Message Size: 64 bytes" "$RESULTS_FILE" | grep "Average:" | awk '{print $3}')
    NET_THR_64=$(grep -A 5 "### Message Size: 64 bytes" "$RESULTS_FILE" | grep "Messages/sec:" | awk '{print $2}')

    # Calculate overhead percentages
    if [ -n "$CPP_LAT_64" ] && [ -n "$NET_LAT_64" ]; then
        LAT_OVERHEAD=$(echo "scale=2; ($NET_LAT_64 / $CPP_LAT_64 - 1) * 100" | bc)
        THR_OVERHEAD=$(echo "scale=2; (1 - $NET_THR_64 / $CPP_THR_64) * 100" | bc)

        cat >> "$RESULTS_FILE" << EOF
### 64-byte Messages

- **Latency Overhead:** ${LAT_OVERHEAD}% (C++: ${CPP_LAT_64} us, .NET: ${NET_LAT_64} us)
- **Throughput Overhead:** ${THR_OVERHEAD}% (C++: ${CPP_THR_64} msg/s, .NET: ${NET_THR_64} msg/s)

EOF
    fi
fi

cat >> "$RESULTS_FILE" << 'EOF'

## Notes

- Latency is measured as round-trip time divided by 2 (one-way latency)
- Throughput measurement excludes the first message (warm-up)
- All tests use tcp://localhost for consistency
- Built with: `dotnet build -c Release` (Optimize=true, TieredCompilation=true)

## Analysis

### P/Invoke Overhead

The performance difference between C++ and .NET is primarily due to:

1. **Managed-to-Native Transitions**: Each ZeroMQ API call involves a P/Invoke call from managed .NET code to native libzmq
2. **Memory Marshaling**: Data must be marshaled between .NET's managed heap and native memory
3. **GC Impact**: Garbage collection can introduce occasional latency spikes
4. **JIT Compilation**: Although tiered compilation is enabled, there may be minor JIT overhead

### Expected Overhead by Message Size

- **Small messages (64B)**: Higher relative overhead due to fixed P/Invoke cost
- **Medium messages (1500B)**: Moderate overhead as marshaling becomes more significant
- **Large messages (65KB)**: Lower relative overhead as data transfer dominates

The overhead is generally acceptable for most real-world applications and is the cost of using .NET's productivity and safety features.

EOF

echo "=========================================="
echo "  Benchmark Complete"
echo "=========================================="
echo
echo "Results saved to: $RESULTS_FILE"
echo

# Clean up temp files
rm -f /tmp/dotnet_local_lat.log /tmp/dotnet_local_thr.log

exit 0
