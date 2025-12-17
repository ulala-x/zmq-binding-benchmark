#!/bin/bash

# ZeroMQ Binding Benchmark - Automated Test Runner
# Runs all language benchmarks and generates analysis

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Timestamp for backups
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}ZeroMQ Binding Benchmark Suite${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Step 1: Validate environment
echo -e "${BLUE}[1/4] Validating environment...${NC}"
if "$SCRIPT_DIR/validate.sh"; then
    echo -e "${GREEN}  ✓ All required tools available${NC}"
else
    echo -e "${RED}  ✗ Environment validation failed${NC}"
    exit 1
fi
echo ""

# Function to backup existing results
backup_results() {
    local result_file=$1
    if [ -f "$result_file" ]; then
        local backup_file="${result_file}.backup_${TIMESTAMP}"
        cp "$result_file" "$backup_file"
        echo -e "${YELLOW}  ⚠ Backed up existing results to: $(basename $backup_file)${NC}"
    fi
}

# Step 2: Run C++ benchmarks
echo -e "${BLUE}[2/4] Running C++ (cppzmq) benchmarks...${NC}"
cd "$PROJECT_ROOT/cpp"

# Backup existing results
backup_results "$PROJECT_ROOT/docs/results/cpp-baseline.md"

# Build
echo -e "  Building..."
if [ -d "build" ]; then
    rm -rf build
fi
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release .. > /dev/null 2>&1
cmake --build . > /dev/null 2>&1
echo -e "${GREEN}  ✓ Build successful${NC}"

# Run benchmarks
echo -e "  Running benchmarks..."
RESULT_FILE="$PROJECT_ROOT/docs/results/cpp-baseline.md"

# Initialize result file with header
cat > "$RESULT_FILE" << EOF
# C++ Baseline Benchmark Results (cppzmq)

**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**System:** $(uname -s) $(uname -r)
**Architecture:** $(uname -m)
**Compiler:** $(c++ --version | head -n 1)

## Test Configuration

- **Latency Rounds:** 10000
- **Throughput Messages:** 1000000
- **Message Sizes:** 64 1500 65536 bytes

## Results

EOF

# Run benchmarks for each message size
for size in 64 1500 65536; do
    echo -e "  Testing $size byte messages..."

    echo "### Message Size: $size bytes" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"

    # Latency test
    ./latency_benchmark tcp://localhost:5555 $size 10000 > /tmp/lat_output.txt &
    LAT_PID=$!
    sleep 0.5
    ./latency_benchmark tcp://localhost:5555 $size 10000 >> /tmp/lat_output.txt
    wait $LAT_PID 2>/dev/null || true

    # Extract latency results
    LAT_AVG=$(grep "Average latency:" /tmp/lat_output.txt | tail -n 1 | awk '{print $3}')
    MSG_RATE=$(grep "Message rate:" /tmp/lat_output.txt | tail -n 1 | awk '{print $3}')

    echo "**Latency:**" >> "$RESULT_FILE"
    echo "- Average: $LAT_AVG us" >> "$RESULT_FILE"
    echo "- Message rate: $MSG_RATE msg/s" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"

    # Throughput test
    ./throughput_benchmark tcp://*:5556 $size 1000000 > /tmp/thr_output.txt &
    THR_PID=$!
    sleep 0.5
    ./throughput_benchmark tcp://localhost:5556 $size 1000000 >> /tmp/thr_output.txt
    wait $THR_PID 2>/dev/null || true

    # Extract throughput results
    THR_MSG=$(grep "Throughput:" /tmp/thr_output.txt | grep "msg/s" | tail -n 1 | awk '{print $2, $3}')
    THR_MB=$(grep "Throughput:" /tmp/thr_output.txt | grep "Mb/s" | tail -n 1 | awk '{print $2, $3}')

    echo "**Throughput:**" >> "$RESULT_FILE"
    echo "- Messages/sec: $THR_MSG" >> "$RESULT_FILE"
    echo "- Megabits/sec: $THR_MB" >> "$RESULT_FILE"
    echo "" >> "$RESULT_FILE"
done

# Add notes section
cat >> "$RESULT_FILE" << 'EOF'

## Notes

- Latency is measured as round-trip time divided by 2 (one-way latency)
- Throughput measurement excludes the first message (warm-up)
- All tests use inproc or tcp://localhost for consistency
- Built with: `-O3 -march=native -flto`

EOF

echo -e "${GREEN}  ✓ Benchmarks complete${NC}"
echo -e "${GREEN}  ✓ Results saved to docs/results/cpp-baseline.md${NC}"
echo ""

# Step 3: Run .NET benchmarks
echo -e "${BLUE}[3/4] Running .NET (net-zmq) benchmarks...${NC}"
cd "$PROJECT_ROOT/dotnet"

# Backup existing results
backup_results "$PROJECT_ROOT/docs/results/dotnet.md"

# Build
echo -e "  Building..."
dotnet build -c Release > /dev/null 2>&1
echo -e "${GREEN}  ✓ Build successful${NC}"

# Run benchmarks
echo -e "  Running benchmarks..."
dotnet run -c Release --no-build > /dev/null 2>&1
echo -e "${GREEN}  ✓ Benchmarks complete${NC}"
echo -e "${GREEN}  ✓ Results saved to docs/results/dotnet.md${NC}"
echo ""

# Step 4: Run Node.js benchmarks
echo -e "${BLUE}[4/4] Running Node.js (zeromq.js) benchmarks...${NC}"
cd "$PROJECT_ROOT/nodejs"

# Backup existing results
backup_results "$PROJECT_ROOT/docs/results/nodejs.md"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "  Installing dependencies..."
    npm install > /dev/null 2>&1
fi

# Run benchmarks
echo -e "  Running benchmarks..."
node benchmark.js > /dev/null 2>&1
echo -e "${GREEN}  ✓ Benchmarks complete${NC}"
echo -e "${GREEN}  ✓ Results saved to docs/results/nodejs.md${NC}"
echo ""

# Step 5: Run analysis
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}All benchmarks completed!${NC}"
echo -e "${CYAN}Running analysis...${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

cd "$PROJECT_ROOT"
python3 "$SCRIPT_DIR/compare.py"

# Check if plots were generated
if [ -f "$PROJECT_ROOT/docs/results/latency_comparison.png" ]; then
    echo ""
    echo -e "${GREEN}✓ Visualization plots generated${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}✓ Complete! All results are in docs/results/${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "Summary files:"
echo -e "  - ${BLUE}docs/SUMMARY.md${NC} (Executive summary)"
echo -e "  - ${BLUE}docs/results/analysis.md${NC} (Detailed analysis)"
echo -e "  - ${BLUE}docs/results/benchmark_data.json${NC} (Raw data)"
echo ""
