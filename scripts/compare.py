#!/usr/bin/env python3

"""
ZeroMQ Binding Benchmark - Result Comparison and Analysis
Parses result files, calculates overhead, and generates detailed analysis
"""

import re
import json
import os
from datetime import datetime
from pathlib import Path


class BenchmarkParser:
    """Parse benchmark result files"""

    def __init__(self, project_root):
        self.project_root = Path(project_root)
        self.results_dir = self.project_root / "docs" / "results"

    def parse_cpp_results(self):
        """Parse C++ baseline results"""
        file_path = self.results_dir / "cpp-baseline.md"
        return self._parse_generic_format(file_path, "C++")

    def parse_dotnet_results(self):
        """Parse .NET results"""
        file_path = self.results_dir / "dotnet.md"
        return self._parse_generic_format(file_path, ".NET")

    def parse_nodejs_results(self):
        """Parse Node.js results"""
        file_path = self.results_dir / "nodejs.md"
        content = file_path.read_text()

        results = {"latency": [], "throughput": []}

        # Parse Node.js format: ">> Message Size: 64 bytes"
        # **Latency:** 85.689 us
        # **Throughput:** 861377 msg/s (441.025 Mb/s)

        size_blocks = re.finditer(
            r">> Message Size: (\d+) bytes\s+"
            r"\*\*Latency:\*\* ([\d.]+) us\s+"
            r"\*\*Throughput:\*\* ([\d.]+) msg/s \(([\d.]+) Mb/s\)",
            content,
        )

        for match in size_blocks:
            size = int(match.group(1))
            latency = float(match.group(2))
            msg_per_sec = float(match.group(3))
            mbps = float(match.group(4))

            results["latency"].append({"size": size, "latency_us": latency})
            results["throughput"].append(
                {"size": size, "msg_per_sec": msg_per_sec, "mbps": mbps}
            )

        return results

    def _parse_generic_format(self, file_path, language):
        """Parse generic markdown format used by C++ and .NET"""
        content = file_path.read_text()
        results = {"latency": [], "throughput": []}

        # Find all message size sections
        size_sections = re.finditer(
            r"### Message Size: (\d+) bytes", content, re.IGNORECASE
        )

        for size_match in size_sections:
            size = int(size_match.group(1))

            # Find the section content (until next ### or end)
            section_start = size_match.end()
            next_section = re.search(r"###", content[section_start:])
            if next_section:
                section_content = content[section_start : section_start + next_section.start()]
            else:
                section_content = content[section_start:]

            # Parse latency
            lat_match = re.search(r"Average:\s*([\d.]+(?:e[+-]?\d+)?)\s*us", section_content)
            if lat_match:
                latency = float(lat_match.group(1))
                results["latency"].append({"size": size, "latency_us": latency})

            # Parse throughput - handle scientific notation
            thr_match = re.search(
                r"Messages/sec:\s*([\d.]+(?:e[+-]?\d+)?(?:E[+-]?\d+)?)\s*msg/s",
                section_content,
                re.IGNORECASE,
            )
            mbps_match = re.search(
                r"Megabits/sec:\s*([\d.]+(?:e[+-]?\d+)?(?:E[+-]?\d+)?)\s*Mb/s",
                section_content,
                re.IGNORECASE,
            )

            if thr_match and mbps_match:
                # Handle both 'e' and 'E' for scientific notation
                msg_str = thr_match.group(1).replace("E", "e")
                mbps_str = mbps_match.group(1).replace("E", "e")

                msg_per_sec = float(msg_str)
                mbps = float(mbps_str)

                results["throughput"].append(
                    {"size": size, "msg_per_sec": msg_per_sec, "mbps": mbps}
                )

        return results


class BenchmarkAnalyzer:
    """Analyze and compare benchmark results"""

    def __init__(self, cpp_results, dotnet_results, nodejs_results):
        self.cpp = cpp_results
        self.dotnet = dotnet_results
        self.nodejs = nodejs_results

    def calculate_overhead(self, baseline, measured):
        """Calculate overhead percentage"""
        if baseline == 0:
            return 0
        return ((measured - baseline) / baseline) * 100

    def calculate_relative_performance(self, baseline, measured):
        """Calculate relative performance percentage"""
        if measured == 0:
            return 0
        return (baseline / measured) * 100

    def generate_analysis_markdown(self):
        """Generate detailed analysis in Markdown format"""

        lines = [
            "# ZeroMQ Binding Performance Comparison",
            "",
            "## Summary",
            "",
            "**Baseline:** C++ (cppzmq)",
            f"**Test Date:** {datetime.now().strftime('%Y-%m-%d')}",
            f"**Platform:** Linux x86_64",
            "",
            "## Latency Comparison (REQ-REP)",
            "",
            "Lower is better. Values show average round-trip latency in microseconds.",
            "",
        ]

        # Group results by message size for latency
        message_sizes = sorted(set(item["size"] for item in self.cpp["latency"]))

        for size in message_sizes:
            lines.append(f"### Message Size: {size} Bytes")
            lines.append("")
            lines.append(
                "| Language | Latency (μs) | vs C++ | Overhead |"
            )
            lines.append("|----------|-------------|--------|----------|")

            # Get data for this size
            cpp_lat = next((x["latency_us"] for x in self.cpp["latency"] if x["size"] == size), None)
            dotnet_lat = next((x["latency_us"] for x in self.dotnet["latency"] if x["size"] == size), None)
            nodejs_lat = next((x["latency_us"] for x in self.nodejs["latency"] if x["size"] == size), None)

            # C++ baseline
            lines.append(f"| C++ (baseline) | {cpp_lat:.3f} | 100% | - |")

            # .NET
            if dotnet_lat:
                rel_perf = self.calculate_relative_performance(cpp_lat, dotnet_lat)
                overhead = self.calculate_overhead(cpp_lat, dotnet_lat)
                overhead_str = f"{overhead:+.1f}%"
                if overhead < 0:
                    overhead_str = f"{overhead:.1f}%"
                lines.append(
                    f"| .NET | {dotnet_lat:.3f} | {rel_perf:.1f}% | {overhead_str} |"
                )

            # Node.js
            if nodejs_lat:
                rel_perf = self.calculate_relative_performance(cpp_lat, nodejs_lat)
                overhead = self.calculate_overhead(cpp_lat, nodejs_lat)
                overhead_str = f"{overhead:+.1f}%"
                lines.append(
                    f"| Node.js | {nodejs_lat:.3f} | {rel_perf:.1f}% | {overhead_str} |"
                )

            lines.append("")

        # Throughput comparison
        lines.extend([
            "## Throughput Comparison (PUSH-PULL)",
            "",
            "Higher is better. Values show messages per second.",
            "",
        ])

        for size in message_sizes:
            lines.append(f"### Message Size: {size} Bytes")
            lines.append("")
            lines.append(
                "| Language | Throughput (msg/s) | Bandwidth (Mb/s) | vs C++ |"
            )
            lines.append("|----------|-------------------|-----------------|--------|")

            # Get data for this size
            cpp_thr = next((x for x in self.cpp["throughput"] if x["size"] == size), None)
            dotnet_thr = next((x for x in self.dotnet["throughput"] if x["size"] == size), None)
            nodejs_thr = next((x for x in self.nodejs["throughput"] if x["size"] == size), None)

            # C++ baseline
            if cpp_thr:
                lines.append(
                    f"| C++ (baseline) | {cpp_thr['msg_per_sec']:,.0f} | "
                    f"{cpp_thr['mbps']:,.3f} | 100% |"
                )

            # .NET
            if dotnet_thr and cpp_thr:
                rel_perf = self.calculate_relative_performance(
                    cpp_thr["msg_per_sec"], dotnet_thr["msg_per_sec"]
                )
                lines.append(
                    f"| .NET | {dotnet_thr['msg_per_sec']:,.0f} | "
                    f"{dotnet_thr['mbps']:,.3f} | {rel_perf:.1f}% |"
                )

            # Node.js
            if nodejs_thr and cpp_thr:
                rel_perf = self.calculate_relative_performance(
                    cpp_thr["msg_per_sec"], nodejs_thr["msg_per_sec"]
                )
                lines.append(
                    f"| Node.js | {nodejs_thr['msg_per_sec']:,.0f} | "
                    f"{nodejs_thr['mbps']:,.3f} | {rel_perf:.1f}% |"
                )

            lines.append("")

        # Key findings
        lines.extend([
            "## Key Findings",
            "",
            "### 1. .NET Performance Characteristics",
            "",
        ])

        # Analyze .NET performance
        dotnet_lat_64 = next((x["latency_us"] for x in self.dotnet["latency"] if x["size"] == 64), None)
        cpp_lat_64 = next((x["latency_us"] for x in self.cpp["latency"] if x["size"] == 64), None)

        if dotnet_lat_64 and cpp_lat_64:
            overhead = self.calculate_overhead(cpp_lat_64, dotnet_lat_64)
            if overhead < 0:
                lines.append(
                    f"**.NET outperforms C++ for small message latency** by {abs(overhead):.1f}%. "
                    "This is remarkable for a managed runtime and demonstrates:"
                )
                lines.extend([
                    "",
                    "- Highly optimized P/Invoke marshaling in Net.Zmq",
                    "- Effective use of Span<T> for zero-copy scenarios",
                    "- JIT compiler producing excellent machine code",
                    "- Minimal GC pressure with careful buffer management",
                    "",
                ])
            else:
                lines.append(
                    f".NET shows {overhead:.1f}% overhead for small messages, "
                    "which is acceptable for a managed runtime."
                )
                lines.append("")

        lines.extend([
            "### 2. Node.js Overhead Pattern",
            "",
            "Node.js demonstrates overhead characteristic of N-API bindings:",
            "",
        ])

        # Calculate Node.js overhead range
        nodejs_overheads = []
        for size in message_sizes:
            cpp_lat = next((x["latency_us"] for x in self.cpp["latency"] if x["size"] == size), None)
            nodejs_lat = next((x["latency_us"] for x in self.nodejs["latency"] if x["size"] == size), None)
            if cpp_lat and nodejs_lat:
                overhead = self.calculate_overhead(cpp_lat, nodejs_lat)
                nodejs_overheads.append(overhead)

        if nodejs_overheads:
            min_oh = min(nodejs_overheads)
            max_oh = max(nodejs_overheads)
            lines.append(
                f"- **{min_oh:.1f}% to {max_oh:.1f}% higher latency** across message sizes"
            )

        lines.extend([
            "",
            "**Key factors:**",
            "- N-API bridge crossing for each operation",
            "- Promise creation/resolution overhead from async/await",
            "- V8 garbage collector and memory management",
            "- Event loop integration adds microtask queue processing",
            "",
        ])

        lines.extend([
            "### 3. Message Size Impact",
            "",
            "**Small Messages (64B):**",
            "- Fixed overhead (call cost, marshaling) dominates",
            "- Per-call overhead is most visible",
            "",
            "**Medium Messages (1500B):**",
            "- Balanced between overhead and data transfer",
            "- Typical Ethernet MTU size",
            "",
            "**Large Messages (65KB):**",
            "- Data transfer dominates, relative overhead decreases",
            "- Memory copying becomes significant factor",
            "",
            "## Performance Recommendations",
            "",
            "### Choose C++ When:",
            "- Absolute maximum performance is required",
            "- Sub-microsecond latency matters",
            "- Building low-level infrastructure",
            "- Working in resource-constrained environments",
            "",
            "### Choose .NET When:",
            "- Building enterprise applications",
            "- Need excellent performance with high productivity",
            "- Want type safety and modern language features",
            "- Latency < 100μs is acceptable",
            "",
            "### Choose Node.js When:",
            "- Building I/O-bound microservices",
            "- Event-driven or real-time applications",
            "- Need integration with Node.js ecosystem",
            "- Latency < 1ms is acceptable",
            "",
            "## Technical Details",
            "",
            "### Measurement Methodology",
            "",
            "**Latency Test:**",
            "- Pattern: REQ/REP (request-reply)",
            "- Measurement: Round-trip time ÷ 2",
            "- Rounds: 10,000",
            "- Timing: High-resolution timers",
            "",
            "**Throughput Test:**",
            "- Pattern: PUSH/PULL (unidirectional)",
            "- Measurement: Messages per second",
            "- Count: 1,000,000 messages",
            "- Warm-up: First message excluded",
            "",
            "### Binding Architectures",
            "",
            "| Aspect | C++ (cppzmq) | .NET (Net.Zmq) | Node.js (zeromq.js) |",
            "|--------|--------------|----------------|---------------------|",
            "| **Binding Type** | Header-only | P/Invoke | N-API |",
            "| **Memory Model** | Manual/RAII | GC with Span<T> | GC with Buffer |",
            "| **Async Model** | Blocking | Blocking | Native async |",
            "| **Zero-Copy** | Full | Partial (Span) | Partial (Buffer) |",
            "",
            "---",
            "",
            f"**Raw data:** `benchmark_data.json`",
            f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "",
        ])

        return "\n".join(lines)

    def generate_json_data(self):
        """Generate JSON data for visualization"""
        return {
            "latency": {
                "C++": self.cpp["latency"],
                ".NET": self.dotnet["latency"],
                "Node.js": self.nodejs["latency"],
            },
            "throughput": {
                "C++": self.cpp["throughput"],
                ".NET": self.dotnet["throughput"],
                "Node.js": self.nodejs["throughput"],
            },
        }


def main():
    """Main execution"""
    # Get project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    print("=" * 50)
    print("ZeroMQ Binding Benchmark - Analysis")
    print("=" * 50)
    print()

    # Parse results
    print("Parsing benchmark results...")
    parser = BenchmarkParser(project_root)

    try:
        cpp_results = parser.parse_cpp_results()
        print("  ✓ C++ baseline parsed")
    except Exception as e:
        print(f"  ✗ Error parsing C++ results: {e}")
        return 1

    try:
        dotnet_results = parser.parse_dotnet_results()
        print("  ✓ .NET results parsed")
    except Exception as e:
        print(f"  ✗ Error parsing .NET results: {e}")
        return 1

    try:
        nodejs_results = parser.parse_nodejs_results()
        print("  ✓ Node.js results parsed")
    except Exception as e:
        print(f"  ✗ Error parsing Node.js results: {e}")
        return 1

    print()

    # Analyze
    print("Analyzing performance data...")
    analyzer = BenchmarkAnalyzer(cpp_results, dotnet_results, nodejs_results)

    # Generate markdown analysis
    analysis_md = analyzer.generate_analysis_markdown()
    analysis_file = project_root / "docs" / "results" / "analysis.md"
    analysis_file.write_text(analysis_md)
    print(f"  ✓ Analysis written to: {analysis_file}")

    # Generate JSON data
    json_data = analyzer.generate_json_data()
    json_file = project_root / "docs" / "results" / "benchmark_data.json"
    json_file.write_text(json.dumps(json_data, indent=2))
    print(f"  ✓ Data written to: {json_file}")

    print()
    print("=" * 50)
    print("✓ Analysis complete!")
    print("=" * 50)
    print()
    print(f"View detailed analysis: {analysis_file}")
    print(f"View raw data: {json_file}")
    print()

    # Try to generate plots
    try:
        plot_script = script_dir / "plot.py"
        if plot_script.exists():
            print("Attempting to generate plots...")
            import subprocess

            result = subprocess.run(
                ["python3", str(plot_script)],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                print("  ✓ Plots generated successfully")
            else:
                print(f"  ⚠ Plot generation skipped: {result.stderr.strip()}")
    except Exception as e:
        print(f"  ⚠ Could not generate plots: {e}")

    return 0


if __name__ == "__main__":
    exit(main())
