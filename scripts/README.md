# Benchmark Automation Scripts

This directory contains automation scripts for running and analyzing ZeroMQ binding benchmarks.

## Overview

The scripts automate the entire benchmark pipeline:
1. Environment validation
2. Building and running benchmarks for all languages
3. Parsing results and generating comparative analysis
4. Creating visualization plots (optional)

## Scripts

### 1. validate.sh

**Purpose:** Validate that all required tools are installed and available.

**Usage:**
```bash
./scripts/validate.sh
```

**Checks:**
- **C++ Tools:**
  - CMake (for building)
  - GCC or Clang compiler

- **.NET Tools:**
  - .NET SDK (8.0+)

- **Node.js Tools:**
  - Node.js runtime
  - npm package manager

- **Python Tools:**
  - Python 3 (for analysis scripts)
  - matplotlib (optional, for plotting)

**Output Example:**
```
========================================
Environment Validation
========================================

[C++]
  ✓ CMake: cmake version 3.28.3
  ✓ GCC: gcc (Ubuntu 13.3.0) 13.3.0

[.NET]
  ✓ .NET SDK: 8.0.122

[Node.js]
  ✓ Node.js: v22.19.0
  ✓ npm: 11.6.0

[Python (for analysis)]
  ✓ Python: Python 3.12.3
  ✗ matplotlib not found (optional for plots)

========================================
Validation Summary
========================================

✓ All required tools are available
⚠ Optional tools missing:
  - matplotlib

Environment is ready for benchmarking!
```

**Exit Codes:**
- `0`: All required tools available
- `1`: Missing required tools

---

### 2. run-all.sh

**Purpose:** Run all benchmarks automatically and generate analysis.

**Usage:**
```bash
./scripts/run-all.sh
```

**What it does:**
1. Validates environment using `validate.sh`
2. Builds and runs C++ benchmarks
3. Builds and runs .NET benchmarks
4. Runs Node.js benchmarks
5. Automatically calls `compare.py` to generate analysis
6. Attempts to generate plots if matplotlib is available

**Features:**
- Backs up existing results with timestamp
- Shows progress for each step
- Saves all results to `docs/results/`
- Generates comprehensive analysis

**Output Example:**
```
========================================
ZeroMQ Binding Benchmark Suite
========================================

[1/4] Validating environment...
  ✓ All required tools available

[2/4] Running C++ (cppzmq) benchmarks...
  Building...
  ✓ Build successful
  Testing 64 byte messages...
  Testing 1500 byte messages...
  Testing 65536 byte messages...
  ✓ Benchmarks complete
  ✓ Results saved to docs/results/cpp-baseline.md

[3/4] Running .NET (net-zmq) benchmarks...
  Building...
  ✓ Build successful
  Running benchmarks...
  ✓ Benchmarks complete
  ✓ Results saved to docs/results/dotnet.md

[4/4] Running Node.js (zeromq.js) benchmarks...
  Running benchmarks...
  ✓ Benchmarks complete
  ✓ Results saved to docs/results/nodejs.md

========================================
All benchmarks completed!
Running analysis...
========================================
```

**Files Generated:**
- `docs/results/cpp-baseline.md` - C++ benchmark results
- `docs/results/dotnet.md` - .NET benchmark results
- `docs/results/nodejs.md` - Node.js benchmark results
- `docs/results/analysis.md` - Detailed comparative analysis
- `docs/results/benchmark_data.json` - Raw data in JSON format
- `docs/results/*.png` - Visualization plots (if matplotlib available)

**Backup:**
Existing results are backed up with timestamp:
- `cpp-baseline.md.backup_20251217_123456`

---

### 3. compare.py

**Purpose:** Parse benchmark results and generate comparative analysis.

**Usage:**
```bash
python3 scripts/compare.py
```

**What it does:**
1. Parses all result markdown files
2. Extracts latency and throughput data
3. Calculates overhead percentages vs C++ baseline
4. Generates detailed analysis in `docs/results/analysis.md`
5. Exports raw data to `docs/results/benchmark_data.json`
6. Automatically attempts to run `plot.py` if available

**Input Files:**
- `docs/results/cpp-baseline.md`
- `docs/results/dotnet.md`
- `docs/results/nodejs.md`

**Output Files:**
- `docs/results/analysis.md` - Comprehensive comparison tables and analysis
- `docs/results/benchmark_data.json` - Structured data for visualization

**Analysis Features:**
- Latency comparison tables (by message size)
- Throughput comparison tables (by message size)
- Overhead calculations (percentage vs C++)
- Relative performance metrics
- Key findings and recommendations
- Technical architecture comparison

**JSON Data Format:**
```json
{
  "latency": {
    "C++": [
      {"size": 64, "latency_us": 56.41},
      {"size": 1500, "latency_us": 53.85},
      {"size": 65536, "latency_us": 66.80}
    ],
    ".NET": [...],
    "Node.js": [...]
  },
  "throughput": {
    "C++": [
      {"size": 64, "msg_per_sec": 5180000, "mbps": 2652.16},
      ...
    ],
    ".NET": [...],
    "Node.js": [...]
  }
}
```

---

### 4. plot.py

**Purpose:** Generate visualization plots from benchmark data.

**Usage:**
```bash
python3 scripts/plot.py
```

**Requirements:**
- Python 3
- matplotlib (`pip3 install matplotlib`)

**What it generates:**

1. **latency_comparison.png**
   - Bar chart comparing latency across languages
   - Grouped by message size
   - Lower is better

2. **throughput_comparison.png**
   - Two subplots:
     - Messages per second comparison
     - Bandwidth (Mb/s) comparison
   - Grouped by message size
   - Higher is better

3. **overhead_comparison.png**
   - Overhead percentage vs C++ baseline
   - Shows which bindings are faster/slower
   - Negative values indicate better performance than C++

**Plot Features:**
- High resolution (300 dpi)
- Clear labels and legends
- Value annotations on bars
- Professional styling
- Grid lines for easier reading

**Output Location:**
All plots are saved to `docs/results/`

**Installing matplotlib:**
```bash
# Ubuntu/Debian
pip3 install matplotlib

# Or system-wide
sudo apt-get install python3-matplotlib
```

---

## Complete Workflow

### Quick Start (Full Pipeline)

```bash
# Run everything
./scripts/run-all.sh
```

This single command will:
1. Validate your environment
2. Run all benchmarks
3. Generate analysis
4. Create plots (if matplotlib available)

### Manual Step-by-Step

```bash
# 1. Check environment
./scripts/validate.sh

# 2. Run C++ benchmarks
cd cpp
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build .
# Run benchmarks manually...

# 3. Run .NET benchmarks
cd ../../dotnet
dotnet run -c Release

# 4. Run Node.js benchmarks
cd ../nodejs
node benchmark.js

# 5. Generate analysis
cd ..
python3 scripts/compare.py

# 6. Generate plots (optional)
python3 scripts/plot.py
```

### Just Regenerate Analysis

If you already have result files and just want to regenerate analysis:

```bash
python3 scripts/compare.py
```

This is useful when you:
- Modify the analysis template
- Want to update the analysis without re-running benchmarks
- Have manually edited result files

---

## Output Files

All output files are stored in `docs/results/`:

```
docs/results/
├── cpp-baseline.md         # C++ benchmark results
├── dotnet.md              # .NET benchmark results
├── nodejs.md              # Node.js benchmark results
├── analysis.md            # Detailed comparative analysis
├── benchmark_data.json    # Raw data in JSON format
├── latency_comparison.png          # Latency chart (optional)
├── throughput_comparison.png       # Throughput chart (optional)
└── overhead_comparison.png         # Overhead chart (optional)
```

## Dependencies

### Required
- **CMake** - Building C++ benchmarks
- **GCC/Clang** - Compiling C++ code
- **.NET SDK** - Building and running .NET benchmarks
- **Node.js & npm** - Running Node.js benchmarks
- **Python 3** - Running analysis scripts

### Optional
- **matplotlib** - Generating visualization plots
  - Install: `pip3 install matplotlib`
  - Not required for analysis, only for plots

## Troubleshooting

### validate.sh fails

**Problem:** Missing required tools

**Solution:** Install the missing tools as indicated in the output:
```bash
# CMake
sudo apt-get install cmake

# GCC/G++
sudo apt-get install build-essential

# .NET SDK
# Follow: https://dotnet.microsoft.com/download

# Node.js
sudo apt-get install nodejs npm

# Python 3
sudo apt-get install python3 python3-pip
```

### Benchmarks fail to run

**Problem:** Build errors or runtime errors

**Solution:**
1. Check that all dependencies are installed
2. Verify libzmq is properly linked
3. Check git submodules are initialized:
   ```bash
   git submodule update --init --recursive
   ```

### Analysis generates empty tables

**Problem:** Result files not found or malformed

**Solution:**
1. Ensure benchmark results exist in `docs/results/`
2. Check that result files follow the expected format
3. Run benchmarks first: `./scripts/run-all.sh`

### Plots not generated

**Problem:** matplotlib not installed

**Solution:**
```bash
pip3 install matplotlib
```

Or skip plotting - the analysis in `analysis.md` is complete without plots.

## Customization

### Modify benchmark parameters

Edit the benchmark source files:
- C++: `cpp/latency_benchmark.cpp`, `cpp/throughput_benchmark.cpp`
- .NET: `dotnet/Program.cs`
- Node.js: `nodejs/benchmark.js`

Then run: `./scripts/run-all.sh`

### Customize analysis format

Edit `scripts/compare.py`:
- Modify the `generate_analysis_markdown()` method
- Customize table formats
- Add new metrics or calculations

Then run: `python3 scripts/compare.py`

### Customize plots

Edit `scripts/plot.py`:
- Change colors, styles, or layouts
- Add new plot types
- Modify chart dimensions

Then run: `python3 scripts/plot.py`

## Performance Tips

### Faster benchmark runs

For quick testing, reduce iteration counts in the source code:
- Latency rounds: 10000 → 1000
- Throughput messages: 1000000 → 100000

### Consistent results

For production benchmarks:
1. Close unnecessary applications
2. Run multiple times and average results
3. Use a dedicated benchmarking machine
4. Disable CPU frequency scaling:
   ```bash
   # Linux
   sudo cpupower frequency-set -g performance
   ```

## Contributing

When adding new language bindings:

1. Create implementation in `<language>/` directory
2. Output results to `docs/results/<language>.md`
3. Follow the markdown format used by existing results
4. Update `scripts/compare.py` to parse your format
5. Update `scripts/run-all.sh` to include your benchmarks
6. Update this README with your language's requirements

## License

MIT License - See LICENSE file in project root.

## References

- [ZeroMQ Guide](https://zguide.zeromq.org/)
- [cppzmq](https://github.com/zeromq/cppzmq)
- [Net.Zmq](https://github.com/ulala-x/net-zmq)
- [zeromq.js](https://github.com/zeromq/zeromq.js)
