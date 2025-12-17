#!/bin/bash
#
# ZeroMQ Node.js Binding Benchmark Runner
#
# This script runs all latency and throughput tests for various message sizes
# and saves the results to ../docs/results/nodejs.md
#

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Test configuration
LATENCY_ROUNDS=10000
THROUGHPUT_MESSAGES=1000000
MESSAGE_SIZES=(64 1500 65536)

# Network endpoints
LAT_ENDPOINT="tcp://127.0.0.1:5555"
THR_ENDPOINT="tcp://127.0.0.1:5556"

# Results file
RESULTS_DIR="../docs/results"
RESULTS_FILE="${RESULTS_DIR}/nodejs.md"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  ZeroMQ Node.js Binding Benchmark  ${NC}"
echo -e "${BLUE}=====================================${NC}"
echo

# Check if npm dependencies are installed
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing npm dependencies...${NC}"
    npm install
    echo
fi

# Get system information
NODE_VERSION=$(node --version)
SYSTEM_INFO=$(uname -s)
KERNEL_VERSION=$(uname -r)
ARCH=$(uname -m)

echo -e "${GREEN}Environment Information:${NC}"
echo "Node.js version: $NODE_VERSION"
echo "System: $SYSTEM_INFO $KERNEL_VERSION"
echo "Architecture: $ARCH"
echo

# Initialize results file
mkdir -p "$RESULTS_DIR"
cat > "$RESULTS_FILE" << EOF
# Node.js Binding Benchmark Results (zeromq.js)

**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**System:** $SYSTEM_INFO $KERNEL_VERSION
**Architecture:** $ARCH
**Node.js Version:** $NODE_VERSION

## Test Configuration

- **Latency Rounds:** $LATENCY_ROUNDS
- **Throughput Messages:** $THROUGHPUT_MESSAGES
- **Message Sizes:** ${MESSAGE_SIZES[@]} bytes

## Results

EOF

# Arrays to store results for comparison table
declare -a LAT_RESULTS
declare -a THR_RESULTS

# Run tests for each message size
for SIZE in "${MESSAGE_SIZES[@]}"; do
    echo -e "${GREEN}Testing with message size: ${SIZE} bytes${NC}"
    echo "----------------------------------------"

    echo ">> Message Size: $SIZE bytes" >> "$RESULTS_FILE"
    echo >> "$RESULTS_FILE"

    # --- LATENCY TEST ---
    echo -e "${YELLOW}Running latency test...${NC}"

    # Start local_lat server in background
    node local-lat.js "tcp://*:5555" "$SIZE" "$LATENCY_ROUNDS" > /dev/null 2>&1 &
    LOCAL_LAT_PID=$!

    # Wait for server to start
    sleep 1

    # Run remote_lat client and capture output
    LAT_OUTPUT=$(node remote-lat.js "$LAT_ENDPOINT" "$SIZE" "$LATENCY_ROUNDS" 2>&1)

    # Wait for server to finish
    wait $LOCAL_LAT_PID 2>/dev/null || true

    # Extract latency value
    LATENCY=$(echo "$LAT_OUTPUT" | grep "average latency:" | awk '{print $3}')

    echo "Latency: $LATENCY us"
    echo "**Latency:** $LATENCY us" >> "$RESULTS_FILE"
    echo >> "$RESULTS_FILE"

    LAT_RESULTS+=("$LATENCY")

    # --- THROUGHPUT TEST ---
    echo -e "${YELLOW}Running throughput test...${NC}"

    # Start local_thr receiver in background
    node local-thr.js "tcp://*:5556" "$SIZE" "$THROUGHPUT_MESSAGES" > /tmp/local_thr_$SIZE.log 2>&1 &
    LOCAL_THR_PID=$!

    # Wait for receiver to start
    sleep 1

    # Run remote_thr sender
    node remote-thr.js "$THR_ENDPOINT" "$SIZE" "$THROUGHPUT_MESSAGES" > /dev/null 2>&1

    # Wait for receiver to finish and capture output
    wait $LOCAL_THR_PID
    THR_OUTPUT=$(cat /tmp/local_thr_$SIZE.log)

    # Extract throughput value
    THROUGHPUT=$(echo "$THR_OUTPUT" | grep "mean throughput:" | grep "msg/s" | awk '{print $3}')
    MEGABITS=$(echo "$THR_OUTPUT" | grep "mean throughput:" | grep "Mb/s" | awk '{print $3}')

    echo "Throughput: $THROUGHPUT msg/s ($MEGABITS Mb/s)"
    echo "**Throughput:** $THROUGHPUT msg/s ($MEGABITS Mb/s)" >> "$RESULTS_FILE"
    echo >> "$RESULTS_FILE"

    THR_RESULTS+=("$THROUGHPUT")

    # Clean up
    rm -f /tmp/local_thr_$SIZE.log

    echo
done

echo -e "${GREEN}All tests completed!${NC}"
echo

# Add comparison with C++ baseline
cat >> "$RESULTS_FILE" << 'EOF'

## Comparison with C++ Baseline

### C++ Baseline Performance

| Message Size | Latency (us) | Throughput (msg/s) |
|--------------|--------------|-------------------|
| 64 bytes     | 56.41        | 5,180,000         |
| 1500 bytes   | 53.85        | 1,170,000         |
| 65536 bytes  | 66.80        | 111,000           |

### Node.js Performance vs C++ Baseline

EOF

# Calculate and add comparison
for i in "${!MESSAGE_SIZES[@]}"; do
    SIZE=${MESSAGE_SIZES[$i]}
    LAT=${LAT_RESULTS[$i]}
    THR=${THR_RESULTS[$i]}

    # C++ baseline values
    case $SIZE in
        64)
            CPP_LAT=56.41
            CPP_THR=5180000
            ;;
        1500)
            CPP_LAT=53.85
            CPP_THR=1170000
            ;;
        65536)
            CPP_LAT=66.80
            CPP_THR=111000
            ;;
    esac

    # Calculate percentage difference using awk for floating point
    LAT_DIFF=$(awk "BEGIN {printf \"%.1f\", (($LAT - $CPP_LAT) / $CPP_LAT) * 100}")
    THR_DIFF=$(awk "BEGIN {printf \"%.1f\", (($THR - $CPP_THR) / $CPP_THR) * 100}")

    cat >> "$RESULTS_FILE" << EOF
#### ${SIZE}-byte Messages

| Metric | C++ Baseline | Node.js | Difference | Performance |
|--------|--------------|---------|------------|-------------|
| **Latency** | ${CPP_LAT} us | ${LAT} us | ${LAT_DIFF}% | $([ ${LAT_DIFF%.*} -lt 0 ] && echo "FASTER ⚡" || echo "slower") |
| **Throughput** | ${CPP_THR} msg/s | ${THR} msg/s | ${THR_DIFF}% | $([ ${THR_DIFF%.*} -lt 0 ] && echo "slower" || echo "FASTER ⚡") |

EOF
done

# Add analysis section
cat >> "$RESULTS_FILE" << 'EOF'

## Analysis

### N-API and V8 Overhead

The performance characteristics of the Node.js zeromq binding are influenced by:

1. **N-API Bridge**: The zeromq.js library uses N-API to bridge JavaScript and native libzmq
2. **V8 Memory Management**: JavaScript Buffers must be managed by V8's garbage collector
3. **Event Loop Integration**: Async operations integrate with Node.js event loop
4. **Promise Overhead**: The async/await pattern adds some overhead for each operation

### Expected Overhead by Message Size

- **Small messages (64B)**: Higher relative overhead due to N-API call cost and async overhead
- **Medium messages (1500B)**: Moderate overhead as data transfer becomes more significant
- **Large messages (65KB)**: Lower relative overhead as data transfer dominates, but still affected by memory copying

### async/await Pattern Impact

The zeromq.js library uses async/await for all socket operations, which:
- Provides clean, readable code and error handling
- Integrates naturally with Node.js event-driven architecture
- Adds overhead for Promise creation and resolution
- Each send/receive involves microtask queue processing

### Comparison with .NET

Comparing Node.js with .NET's Net.Zmq binding shows interesting patterns:
- Both use native bindings (N-API vs P/Invoke)
- Both have managed memory overhead
- .NET may have advantages with Span<T> and unsafe code for large buffers
- Node.js may have advantages with simpler async model

## Notes

- Latency is measured as round-trip time divided by 2 (one-way latency)
- Throughput measurement excludes the first message (warm-up)
- All tests use tcp://127.0.0.1 for consistency
- Tests run with Node.js default settings (no special V8 flags)

EOF

echo -e "${BLUE}Results saved to: ${RESULTS_FILE}${NC}"
echo -e "${GREEN}Benchmark complete!${NC}"
