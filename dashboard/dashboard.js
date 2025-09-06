class NeoverseDashboard {
    constructor() {
        this.data = {
            baseline: {},
            optimizations: [],
            systemInfo: {}
        };
        this.charts = {};
        this.updateInterval = null;
        
        this.init();
    }

    init() {
        this.loadSystemInfo();
        this.loadData();
        this.initCharts();
        this.startAutoRefresh();
        
        // Set up event listeners
        document.addEventListener('DOMContentLoaded', () => {
            this.updateDisplay();
        });
    }

    async loadSystemInfo() {
        try {
            const response = await fetch('../results/hardware_info.txt');
            if (response.ok) {
                const text = await response.text();
                this.parseSystemInfo(text);
            }
        } catch (error) {
            console.log('System info not available');
            document.getElementById('processor-info').textContent = 'Neoverse System';
        }
    }

    parseSystemInfo(text) {
        const lines = text.split('\n');
        let processor = 'Unknown';
        
        lines.forEach(line => {
            if (line.includes('Model name')) {
                processor = line.split(':')[1].trim();
            }
        });
        
        document.getElementById('processor-info').textContent = processor;
    }

    async loadData() {
        try {
            // Load baseline results
            await this.loadBaseline();
            
            // Load latest optimization results
            await this.loadOptimizations();
            
            this.updateDisplay();
            this.updateCharts();
            
        } catch (error) {
            console.error('Error loading data:', error);
            this.showError('Failed to load benchmark data');
        }
    }

    async loadBaseline() {
        try {
            const response = await fetch('../results/baseline_summary.txt');
            if (response.ok) {
                const text = await response.text();
                this.data.baseline = this.parseBaseline(text);
            }
        } catch (error) {
            console.log('Baseline data not available');
        }
    }

    parseBaseline(text) {
        const results = {};
        const lines = text.split('\n');
        
        lines.forEach(line => {
            if (line.includes(':')) {
                const [size, gflops] = line.split(':').map(s => s.trim());
                results[size] = parseFloat(gflops);
            }
        });
        
        return results;
    }

    async loadOptimizations() {
        // Simulate loading recent test results
        // In real implementation, this would parse actual result files
        this.data.optimizations = [
            { rank: 1, gflops: 4.56, time: 0.000, gflop_per_s: '∞', opt: '-O2', march: 'Autodetect', mtune: 'Autodetect', size: 'micro' },
            { rank: 2, gflops: 4.50, time: 0.000, gflop_per_s: '∞', opt: '-O3', march: 'None', mtune: 'None', size: 'micro' },
            { rank: 3, gflops: 2.59, time: 0.104, gflop_per_s: 24.90, opt: '-O3', march: 'V2', mtune: 'V2', size: 'small' },
            { rank: 4, gflops: 2.58, time: 0.104, gflop_per_s: 24.80, opt: '-O2', march: 'V2', mtune: 'V2', size: 'small' },
            { rank: 5, gflops: 0.72, time: 23.896, gflop_per_s: 0.03, opt: '-O3', march: 'Autodetect', mtune: 'Autodetect', size: 'medium' }
        ];
    }

    updateDisplay() {
        if (this.data.optimizations.length === 0) return;

        const best = this.data.optimizations[0];
        const baseline = this.data.baseline['small'] || 0.66;
        const improvement = ((best.gflops - baseline) / baseline * 100).toFixed(1);

        // Update metrics
        document.getElementById('best-gflops').textContent = best.gflops.toFixed(2);
        document.getElementById('improvement').textContent = `+${improvement}% vs baseline`;
        document.getElementById('best-opt').textContent = best.opt;
        document.getElementById('best-flags').textContent = `${best.march}/${best.mtune}`;
        document.getElementById('optimal-size').textContent = best.size;
        document.getElementById('size-efficiency').textContent = `${best.gflop_per_s} GFLOP/s`;
        document.getElementById('test-time').textContent = '2.8';
        document.getElementById('parallel-jobs').textContent = '16 parallel jobs';

        // Update results table
        this.updateResultsTable();
    }

    updateResultsTable() {
        const tbody = document.getElementById('results-body');
        tbody.innerHTML = '';

        this.data.optimizations.forEach(result => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${result.rank}</td>
                <td>${result.gflops.toFixed(2)}</td>
                <td>${result.time.toFixed(3)}</td>
                <td>${result.gflop_per_s}</td>
                <td>${result.opt}</td>
                <td>${result.march}</td>
                <td>${result.mtune}</td>
                <td>${result.size}</td>
            `;
            tbody.appendChild(row);
        });
    }

    initCharts() {
        this.initPerformanceChart();
        this.initOptimizationChart();
    }

    initPerformanceChart() {
        const ctx = document.getElementById('performanceChart').getContext('2d');
        
        this.charts.performance = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ['Micro (64x64)', 'Small (512x512)', 'Medium (2048x2048)'],
                datasets: [{
                    label: 'Best Performance (GFLOPS)',
                    data: [4.56, 2.59, 0.72],
                    backgroundColor: [
                        'rgba(52, 152, 219, 0.8)',
                        'rgba(46, 204, 113, 0.8)',
                        'rgba(155, 89, 182, 0.8)'
                    ],
                    borderColor: [
                        'rgba(52, 152, 219, 1)',
                        'rgba(46, 204, 113, 1)',
                        'rgba(155, 89, 182, 1)'
                    ],
                    borderWidth: 2,
                    borderRadius: 8
                }, {
                    label: 'Baseline (GFLOPS)',
                    data: [0.74, 0.66, 0.56],
                    backgroundColor: 'rgba(231, 76, 60, 0.6)',
                    borderColor: 'rgba(231, 76, 60, 1)',
                    borderWidth: 2,
                    borderRadius: 8
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'top',
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'GFLOPS'
                        }
                    }
                }
            }
        });
    }

    initOptimizationChart() {
        const ctx = document.getElementById('optimizationChart').getContext('2d');
        
        this.charts.optimization = new Chart(ctx, {
            type: 'line',
            data: {
                labels: ['-O0', '-O1', '-O2', '-O3'],
                datasets: [{
                    label: 'Micro Matrix',
                    data: [0.74, 4.13, 4.56, 4.50],
                    borderColor: 'rgba(52, 152, 219, 1)',
                    backgroundColor: 'rgba(52, 152, 219, 0.1)',
                    tension: 0.4,
                    fill: true
                }, {
                    label: 'Small Matrix',
                    data: [0.66, 2.41, 2.58, 2.59],
                    borderColor: 'rgba(46, 204, 113, 1)',
                    backgroundColor: 'rgba(46, 204, 113, 0.1)',
                    tension: 0.4,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'top',
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'GFLOPS'
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Optimization Level'
                        }
                    }
                }
            }
        });
    }

    updateCharts() {
        // Update chart data when new results are available
        if (this.charts.performance && this.data.optimizations.length > 0) {
            // Update with real data
            this.charts.performance.update();
        }
        
        if (this.charts.optimization) {
            this.charts.optimization.update();
        }
    }

    startAutoRefresh() {
        this.updateInterval = setInterval(() => {
            this.loadData();
        }, 5000); // Refresh every 5 seconds
    }

    showError(message) {
        const tbody = document.getElementById('results-body');
        tbody.innerHTML = `<tr><td colspan="8" class="loading" style="color: #e74c3c;">${message}</td></tr>`;
    }
}

// Global functions for UI interactions
function refreshData() {
    const btn = document.querySelector('.refresh-btn i');
    btn.style.animation = 'spin 1s linear';
    
    dashboard.loadData();
    
    setTimeout(() => {
        btn.style.animation = '';
    }, 1000);
}

function runBenchmark() {
    const testType = document.getElementById('test-type').value;
    const btn = document.querySelector('.run-test-btn');
    
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Running...';
    btn.disabled = true;
    
    // Simulate benchmark run
    setTimeout(() => {
        btn.innerHTML = '<i class="fas fa-play"></i> Run Test';
        btn.disabled = false;
        dashboard.loadData();
    }, 3000);
}

// Add CSS animation for refresh button
const style = document.createElement('style');
style.textContent = `
    @keyframes spin {
        from { transform: rotate(0deg); }
        to { transform: rotate(360deg); }
    }
`;
document.head.appendChild(style);

// Initialize dashboard
const dashboard = new NeoverseDashboard();
