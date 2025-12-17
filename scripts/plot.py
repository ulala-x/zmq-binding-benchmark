#!/usr/bin/env python3

"""
ZeroMQ Binding Benchmark - Visualization
Generates comparison plots from benchmark data
"""

import json
import sys
from pathlib import Path

try:
    import matplotlib.pyplot as plt
    import matplotlib.ticker as ticker
    import numpy as np
except ImportError:
    print("Error: matplotlib is not installed")
    print("Install with: pip3 install matplotlib")
    sys.exit(1)


def format_large_number(value, pos=None):
    """Format large numbers with K/M suffix"""
    if value >= 1_000_000:
        return f"{value/1_000_000:.1f}M"
    elif value >= 1_000:
        return f"{value/1_000:.0f}K"
    else:
        return f"{value:.0f}"


def plot_latency_comparison(data, output_dir):
    """Generate latency comparison bar chart"""
    # Extract data
    languages = ["C++", ".NET", "Node.js"]
    colors = ["#3498db", "#2ecc71", "#e74c3c"]

    # Get message sizes
    sizes = sorted(set(item["size"] for item in data["latency"]["C++"]))
    size_labels = [f"{s}B" if s < 1024 else f"{s//1024}KB" for s in sizes]

    # Prepare data for plotting
    latencies = {lang: [] for lang in languages}

    for size in sizes:
        for lang in languages:
            lat_data = next(
                (x["latency_us"] for x in data["latency"][lang] if x["size"] == size),
                None,
            )
            latencies[lang].append(lat_data if lat_data else 0)

    # Create plot
    fig, ax = plt.subplots(figsize=(12, 6))

    x = np.arange(len(sizes))
    width = 0.25

    for idx, lang in enumerate(languages):
        offset = (idx - 1) * width
        bars = ax.bar(
            x + offset,
            latencies[lang],
            width,
            label=lang,
            color=colors[idx],
            alpha=0.8,
        )

        # Add value labels on bars
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(
                    bar.get_x() + bar.get_width() / 2.0,
                    height,
                    f"{height:.1f}",
                    ha="center",
                    va="bottom",
                    fontsize=9,
                )

    ax.set_xlabel("Message Size", fontsize=12, fontweight="bold")
    ax.set_ylabel("Latency (μs)", fontsize=12, fontweight="bold")
    ax.set_title(
        "ZeroMQ Binding Latency Comparison\n(Lower is Better)",
        fontsize=14,
        fontweight="bold",
    )
    ax.set_xticks(x)
    ax.set_xticklabels(size_labels)
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3, axis="y")

    plt.tight_layout()
    output_file = output_dir / "latency_comparison.png"
    plt.savefig(output_file, dpi=300, bbox_inches="tight")
    print(f"  ✓ Latency chart saved to: {output_file}")
    plt.close()


def plot_throughput_comparison(data, output_dir):
    """Generate throughput comparison charts"""
    languages = ["C++", ".NET", "Node.js"]
    colors = ["#3498db", "#2ecc71", "#e74c3c"]

    # Get message sizes
    sizes = sorted(set(item["size"] for item in data["throughput"]["C++"]))
    size_labels = [f"{s}B" if s < 1024 else f"{s//1024}KB" for s in sizes]

    # Prepare data
    msg_per_sec = {lang: [] for lang in languages}
    mbps = {lang: [] for lang in languages}

    for size in sizes:
        for lang in languages:
            thr_data = next(
                (x for x in data["throughput"][lang] if x["size"] == size),
                None,
            )
            if thr_data:
                msg_per_sec[lang].append(thr_data["msg_per_sec"])
                mbps[lang].append(thr_data["mbps"])
            else:
                msg_per_sec[lang].append(0)
                mbps[lang].append(0)

    # Create subplots
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))

    x = np.arange(len(sizes))
    width = 0.25

    # Plot 1: Messages per second
    for idx, lang in enumerate(languages):
        offset = (idx - 1) * width
        bars = ax1.bar(
            x + offset,
            msg_per_sec[lang],
            width,
            label=lang,
            color=colors[idx],
            alpha=0.8,
        )

        # Add value labels
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax1.text(
                    bar.get_x() + bar.get_width() / 2.0,
                    height,
                    format_large_number(height),
                    ha="center",
                    va="bottom",
                    fontsize=9,
                )

    ax1.set_xlabel("Message Size", fontsize=12, fontweight="bold")
    ax1.set_ylabel("Messages/sec", fontsize=12, fontweight="bold")
    ax1.set_title(
        "ZeroMQ Binding Throughput Comparison - Messages per Second\n(Higher is Better)",
        fontsize=14,
        fontweight="bold",
    )
    ax1.set_xticks(x)
    ax1.set_xticklabels(size_labels)
    ax1.legend(fontsize=11)
    ax1.grid(True, alpha=0.3, axis="y")
    ax1.yaxis.set_major_formatter(ticker.FuncFormatter(format_large_number))

    # Plot 2: Bandwidth (Mb/s)
    for idx, lang in enumerate(languages):
        offset = (idx - 1) * width
        bars = ax2.bar(
            x + offset,
            mbps[lang],
            width,
            label=lang,
            color=colors[idx],
            alpha=0.8,
        )

        # Add value labels
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax2.text(
                    bar.get_x() + bar.get_width() / 2.0,
                    height,
                    format_large_number(height),
                    ha="center",
                    va="bottom",
                    fontsize=9,
                )

    ax2.set_xlabel("Message Size", fontsize=12, fontweight="bold")
    ax2.set_ylabel("Bandwidth (Mb/s)", fontsize=12, fontweight="bold")
    ax2.set_title(
        "ZeroMQ Binding Throughput Comparison - Bandwidth\n(Higher is Better)",
        fontsize=14,
        fontweight="bold",
    )
    ax2.set_xticks(x)
    ax2.set_xticklabels(size_labels)
    ax2.legend(fontsize=11)
    ax2.grid(True, alpha=0.3, axis="y")
    ax2.yaxis.set_major_formatter(ticker.FuncFormatter(format_large_number))

    plt.tight_layout()
    output_file = output_dir / "throughput_comparison.png"
    plt.savefig(output_file, dpi=300, bbox_inches="tight")
    print(f"  ✓ Throughput chart saved to: {output_file}")
    plt.close()


def plot_overhead_analysis(data, output_dir):
    """Generate overhead analysis chart"""
    sizes = sorted(set(item["size"] for item in data["latency"]["C++"]))
    size_labels = [f"{s}B" if s < 1024 else f"{s//1024}KB" for s in sizes]

    # Calculate overhead percentages
    dotnet_overhead = []
    nodejs_overhead = []

    for size in sizes:
        cpp_lat = next((x["latency_us"] for x in data["latency"]["C++"] if x["size"] == size), None)
        dotnet_lat = next((x["latency_us"] for x in data["latency"][".NET"] if x["size"] == size), None)
        nodejs_lat = next((x["latency_us"] for x in data["latency"]["Node.js"] if x["size"] == size), None)

        if cpp_lat and dotnet_lat:
            dotnet_overhead.append(((dotnet_lat - cpp_lat) / cpp_lat) * 100)
        else:
            dotnet_overhead.append(0)

        if cpp_lat and nodejs_lat:
            nodejs_overhead.append(((nodejs_lat - cpp_lat) / cpp_lat) * 100)
        else:
            nodejs_overhead.append(0)

    # Create plot
    fig, ax = plt.subplots(figsize=(12, 7))

    x = np.arange(len(sizes))
    width = 0.35

    bars1 = ax.bar(
        x - width / 2,
        dotnet_overhead,
        width,
        label=".NET",
        color="#2ecc71",
        alpha=0.8,
    )
    bars2 = ax.bar(
        x + width / 2,
        nodejs_overhead,
        width,
        label="Node.js",
        color="#e74c3c",
        alpha=0.8,
    )

    # Add value labels
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            label = f"{height:+.1f}%"
            va = "bottom" if height >= 0 else "top"
            ax.text(
                bar.get_x() + bar.get_width() / 2.0,
                height,
                label,
                ha="center",
                va=va,
                fontsize=10,
                fontweight="bold",
            )

    ax.set_xlabel("Message Size", fontsize=12, fontweight="bold")
    ax.set_ylabel("Overhead vs C++ Baseline (%)", fontsize=12, fontweight="bold")
    ax.set_title(
        "Latency Overhead Comparison vs C++ Baseline\n(Negative = Faster than C++)",
        fontsize=14,
        fontweight="bold",
    )
    ax.set_xticks(x)
    ax.set_xticklabels(size_labels)
    ax.legend(fontsize=11)
    ax.grid(True, alpha=0.3, axis="y")
    ax.axhline(y=0, color="black", linestyle="-", linewidth=1)

    plt.tight_layout()
    output_file = output_dir / "overhead_comparison.png"
    plt.savefig(output_file, dpi=300, bbox_inches="tight")
    print(f"  ✓ Overhead chart saved to: {output_file}")
    plt.close()


def main():
    """Main execution"""
    # Get project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    results_dir = project_root / "docs" / "results"

    # Load data
    json_file = results_dir / "benchmark_data.json"

    if not json_file.exists():
        print(f"Error: {json_file} not found")
        print("Run compare.py first to generate the data file")
        return 1

    print("Generating visualization plots...")
    print()

    with open(json_file, "r") as f:
        data = json.load(f)

    # Generate plots
    plot_latency_comparison(data, results_dir)
    plot_throughput_comparison(data, results_dir)
    plot_overhead_analysis(data, results_dir)

    print()
    print("=" * 50)
    print("✓ All plots generated successfully!")
    print("=" * 50)
    print()
    print(f"Output directory: {results_dir}")
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
