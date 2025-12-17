#!/bin/bash

#
# ZeroMQ C++ Benchmark Runner
#
# Automatically runs latency and throughput tests with multiple message sizes.
# Saves results to docs/results/cpp-baseline.md
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Benchmark parameters
MESSAGE_SIZES=(64 1500 65536)
LATENCY_ROUNDS=50000
THROUGHPUT_MESSAGES=5000000

# Ports
LAT_PORT=5555
THR_PORT=5556

# Build directory
BUILD_DIR="build"

# Output file
OUTPUT_FILE="../docs/results/cpp-baseline.md"

echo -e "${GREEN}=== ZeroMQ C++ Benchmark ===${NC}"
echo ""

# Check if binaries exist
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${RED}Error: Build directory not found. Please build the project first.${NC}"
    echo "Run: mkdir build && cd build && cmake .. && make"
    exit 1
fi

if [ ! -f "$BUILD_DIR/local_lat" ] || [ ! -f "$BUILD_DIR/remote_lat" ] || \
   [ ! -f "$BUILD_DIR/local_thr" ] || [ ! -f "$BUILD_DIR/remote_thr" ]; then
    echo -e "${RED}Error: Benchmark executables not found. Please build the project first.${NC}"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Initialize output file
cat > "$OUTPUT_FILE" << EOF
# C++ Baseline Benchmark Results (cppzmq)

**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**System:** $(uname -s) $(uname -r)
**Architecture:** $(uname -m)
**Compiler:** $(c++ --version | head -n 1)

## Test Configuration

- **Latency Rounds:** ${LATENCY_ROUNDS}
- **Throughput Messages:** ${THROUGHPUT_MESSAGES}
- **Message Sizes:** ${MESSAGE_SIZES[@]} bytes

## Results

EOF

echo -e "${YELLOW}Starting benchmarks...${NC}"
echo ""

# Run benchmarks for each message size
for size in "${MESSAGE_SIZES[@]}"; do
    echo -e "${GREEN}Testing with message size: ${size} bytes${NC}"
    echo ""

    # ===========================
    # Latency Test
    # ===========================
    echo -e "${YELLOW}  [1/2] Running latency test...${NC}"

    # Start local_lat in background
    "$BUILD_DIR/local_lat" "tcp://*:${LAT_PORT}" "$size" "$LATENCY_ROUNDS" > /tmp/lat_local.txt 2>&1 &
    LOCAL_LAT_PID=$!

    # Wait for server to start
    sleep 1

    # Run remote_lat
    "$BUILD_DIR/remote_lat" "tcp://localhost:${LAT_PORT}" "$size" "$LATENCY_ROUNDS" > /tmp/lat_remote.txt 2>&1

    # Wait for local_lat to finish
    wait $LOCAL_LAT_PID

    # Extract latency result
    LATENCY=$(grep "Average latency:" /tmp/lat_remote.txt | awk '{print $3}')
    MSG_RATE=$(grep "Message rate:" /tmp/lat_remote.txt | awk '{print $3}')

    echo -e "    Latency: ${GREEN}${LATENCY} us${NC}"
    echo -e "    Message rate: ${GREEN}${MSG_RATE} msg/s${NC}"
    echo ""

    # ===========================
    # Throughput Test
    # ===========================
    echo -e "${YELLOW}  [2/2] Running throughput test...${NC}"

    # Start local_thr in background
    "$BUILD_DIR/local_thr" "tcp://*:${THR_PORT}" "$size" "$THROUGHPUT_MESSAGES" > /tmp/thr_local.txt 2>&1 &
    LOCAL_THR_PID=$!

    # Wait for server to start
    sleep 1

    # Run remote_thr
    "$BUILD_DIR/remote_thr" "tcp://localhost:${THR_PORT}" "$size" "$THROUGHPUT_MESSAGES" > /tmp/thr_remote.txt 2>&1

    # Wait for local_thr to finish
    wait $LOCAL_THR_PID

    # Extract throughput results
    THROUGHPUT=$(grep "Throughput:" /tmp/thr_local.txt | head -n 1 | awk '{print $2}')
    MBPS=$(grep "Throughput:" /tmp/thr_local.txt | tail -n 1 | awk '{print $2}')

    echo -e "    Throughput: ${GREEN}${THROUGHPUT} msg/s${NC}"
    echo -e "    Throughput: ${GREEN}${MBPS} Mb/s${NC}"
    echo ""

    # Append to output file
    cat >> "$OUTPUT_FILE" << EOF
### Message Size: ${size} bytes

**Latency:**
- Average: ${LATENCY} us
- Message rate: ${MSG_RATE} msg/s

**Throughput:**
- Messages/sec: ${THROUGHPUT} msg/s
- Megabits/sec: ${MBPS} Mb/s

EOF

    # Small delay between tests
    sleep 1
done

# Add footer to output file
cat >> "$OUTPUT_FILE" << EOF

## Notes

- Latency is measured as round-trip time divided by 2 (one-way latency)
- Throughput measurement excludes the first message (warm-up)
- All tests use inproc or tcp://localhost for consistency
- Built with: \`-O3 -march=native -flto\`

## Raw Test Output

### Latency Test (Last Run)
\`\`\`
$(cat /tmp/lat_remote.txt)
\`\`\`

### Throughput Test (Last Run)
\`\`\`
$(cat /tmp/thr_local.txt)
\`\`\`
EOF

# Cleanup temp files
rm -f /tmp/lat_local.txt /tmp/lat_remote.txt /tmp/thr_local.txt /tmp/thr_remote.txt

echo -e "${GREEN}=== Benchmark Complete ===${NC}"
echo ""
echo -e "Results saved to: ${GREEN}${OUTPUT_FILE}${NC}"
echo ""

# Display results
cat "$OUTPUT_FILE"
