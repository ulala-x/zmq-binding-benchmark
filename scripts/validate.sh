#!/bin/bash

# ZeroMQ Binding Benchmark - Environment Validation Script
# Checks for required tools and dependencies

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check marks
CHECK_MARK="${GREEN}✓${NC}"
CROSS_MARK="${RED}✗${NC}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Environment Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Track if all required tools are available
ALL_REQUIRED_OK=true
OPTIONAL_MISSING=()

# Function to check if command exists
check_command() {
    local cmd=$1
    local name=$2
    local required=$3
    local version_flag=${4:---version}

    if command -v "$cmd" &> /dev/null; then
        local version_output=$($cmd $version_flag 2>&1 | head -n 1)
        echo -e "  $CHECK_MARK $name: $version_output"
        return 0
    else
        if [ "$required" = true ]; then
            echo -e "  $CROSS_MARK $name not found (REQUIRED)"
            ALL_REQUIRED_OK=false
        else
            echo -e "  $CROSS_MARK $name not found (optional)"
            OPTIONAL_MISSING+=("$name")
        fi
        return 1
    fi
}

# Check C++ tools
echo -e "${BLUE}[C++]${NC}"
check_command cmake "CMake" true
if command -v g++ &> /dev/null; then
    check_command g++ "GCC" true
elif command -v clang++ &> /dev/null; then
    check_command clang++ "Clang" true
else
    echo -e "  $CROSS_MARK No C++ compiler found (GCC or Clang required)"
    ALL_REQUIRED_OK=false
fi
echo ""

# Check .NET tools
echo -e "${BLUE}[.NET]${NC}"
check_command dotnet ".NET SDK" true
echo ""

# Check Node.js tools
echo -e "${BLUE}[Node.js]${NC}"
check_command node "Node.js" true -v
check_command npm "npm" true -v
echo ""

# Check Python tools for analysis
echo -e "${BLUE}[Python (for analysis)]${NC}"
check_command python3 "Python" true

# Check for Python packages
if command -v python3 &> /dev/null; then
    # Check matplotlib
    if python3 -c "import matplotlib" 2>/dev/null; then
        local mpl_version=$(python3 -c "import matplotlib; print(matplotlib.__version__)" 2>/dev/null)
        echo -e "  $CHECK_MARK matplotlib: $mpl_version"
    else
        echo -e "  $CROSS_MARK matplotlib not found (optional for plots)"
        OPTIONAL_MISSING+=("matplotlib")
    fi
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$ALL_REQUIRED_OK" = true ]; then
    echo -e "${GREEN}✓ All required tools are available${NC}"

    if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Optional tools missing:${NC}"
        for tool in "${OPTIONAL_MISSING[@]}"; do
            echo -e "  - $tool"
        done
        echo ""
        echo -e "To install matplotlib (for plotting):"
        echo -e "  ${BLUE}pip3 install matplotlib${NC}"
    fi
    echo ""
    echo -e "${GREEN}Environment is ready for benchmarking!${NC}"
    exit 0
else
    echo -e "${RED}✗ Missing required tools${NC}"
    echo -e ""
    echo -e "Please install the missing tools and try again."
    echo -e ""
    echo -e "Installation hints:"
    echo -e "  CMake:     sudo apt-get install cmake"
    echo -e "  GCC:       sudo apt-get install build-essential"
    echo -e "  .NET:      https://dotnet.microsoft.com/download"
    echo -e "  Node.js:   https://nodejs.org/ or sudo apt-get install nodejs npm"
    echo -e "  Python3:   sudo apt-get install python3 python3-pip"
    exit 1
fi
