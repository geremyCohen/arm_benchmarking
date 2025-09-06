# Neoverse Optimization Dashboard

A professional, framework-based realtime dashboard for monitoring Neoverse processor optimization benchmarks.

## Features

🚀 **Professional Interface**
- Modern glassmorphism design with gradient backgrounds
- Responsive layout that works on desktop and mobile
- Real-time metrics and performance indicators

📊 **Interactive Charts**
- Performance comparison by matrix size
- Optimization level analysis with Chart.js
- Live updating visualizations

⚡ **Realtime Updates**
- Auto-refresh every 5 seconds
- Live benchmark execution monitoring
- Instant result updates

🎯 **Key Metrics**
- Best GFLOPS performance
- Optimization level recommendations
- Compiler flag analysis (-march/-mtune)
- Performance improvement percentages

## Quick Start

```bash
# Start the dashboard server
cd dashboard
python3 server.py

# Open in browser
http://localhost:8080
```

## Dashboard Sections

### 1. Performance Overview
- **Best GFLOPS**: Highest performance achieved
- **Improvement**: Percentage gain over baseline
- **Optimization Level**: Best performing compiler flags
- **Test Duration**: Parallel execution time

### 2. Interactive Charts
- **Performance by Matrix Size**: Bar chart comparing micro/small/medium matrices
- **Optimization Comparison**: Line chart showing -O0 through -O3 performance

### 3. Results Table
- **Live Results**: Real-time benchmark data
- **Run Tests**: Execute benchmarks directly from dashboard
- **Detailed Metrics**: GFLOPS, timing, compiler flags per test

### 4. System Information
- **Processor Detection**: Automatic Neoverse variant identification
- **Core Count**: Parallel execution capabilities
- **Status Indicator**: Live system monitoring

## API Endpoints

```bash
GET  /api/data     # Get benchmark results
GET  /api/system   # Get system information  
POST /api/run-benchmark  # Execute benchmark
```

## Technology Stack

- **Frontend**: Vanilla JavaScript + Chart.js + Modern CSS
- **Backend**: Python HTTP server with API endpoints
- **Styling**: CSS Grid + Flexbox + Glassmorphism effects
- **Charts**: Chart.js for interactive visualizations
- **Icons**: Font Awesome for professional iconography

## Integration

The dashboard automatically reads from:
- `../results/baseline_summary.txt` - Baseline performance data
- `../results/hardware_info.txt` - System information
- `../scripts/03/run-baseline.sh` - Benchmark execution

## Professional Features

✨ **Modern Design**
- Glassmorphism effects with backdrop blur
- Smooth animations and hover effects
- Professional color scheme and typography

🔄 **Live Updates**
- File system monitoring for result changes
- WebSocket-ready architecture for real-time data
- Background benchmark execution

📱 **Responsive**
- Mobile-friendly responsive design
- Adaptive grid layouts
- Touch-friendly controls

This replaces any existing basic dashboard with a professional, framework-based solution suitable for production monitoring of Neoverse optimization benchmarks.
