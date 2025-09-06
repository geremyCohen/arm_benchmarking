const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const chokidar = require('chokidar');
const fs = require('fs');
const path = require('path');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "http://localhost:3000",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());
app.use(express.static('client/build'));

// Store benchmark results
let benchmarkData = {
  baseline: {},
  optimizations: [],
  realtime: [],
  systemInfo: {}
};

// Watch for result file changes
const resultsPath = path.join(__dirname, '../results');
const watcher = chokidar.watch(resultsPath, {ignored: /^\./, persistent: true});

watcher.on('change', (filePath) => {
  console.log('File changed:', filePath);
  loadBenchmarkData();
  io.emit('dataUpdate', benchmarkData);
});

// Load benchmark data from files
function loadBenchmarkData() {
  try {
    // Load baseline results
    const baselinePath = path.join(resultsPath, 'baseline_summary.txt');
    if (fs.existsSync(baselinePath)) {
      const baseline = fs.readFileSync(baselinePath, 'utf8');
      benchmarkData.baseline = parseBaselineResults(baseline);
    }

    // Load optimization results
    const optimizationFiles = fs.readdirSync(resultsPath)
      .filter(file => file.includes('optimization') && file.endsWith('.txt'));
    
    benchmarkData.optimizations = optimizationFiles.map(file => {
      const content = fs.readFileSync(path.join(resultsPath, file), 'utf8');
      return parseOptimizationResults(content, file);
    });

    // Load system info
    const hwPath = path.join(resultsPath, 'hardware_info.txt');
    if (fs.existsSync(hwPath)) {
      benchmarkData.systemInfo = parseSystemInfo(fs.readFileSync(hwPath, 'utf8'));
    }

  } catch (error) {
    console.error('Error loading benchmark data:', error);
  }
}

function parseBaselineResults(content) {
  const lines = content.split('\n');
  const results = {};
  
  lines.forEach(line => {
    if (line.includes(':')) {
      const [size, gflops] = line.split(':').map(s => s.trim());
      results[size] = parseFloat(gflops);
    }
  });
  
  return results;
}

function parseOptimizationResults(content, filename) {
  const lines = content.split('\n');
  const result = {
    name: filename.replace('.txt', ''),
    timestamp: new Date().toISOString(),
    results: {}
  };
  
  lines.forEach(line => {
    if (line.includes('GFLOPS')) {
      const match = line.match(/(\d+\.?\d*)\s+GFLOPS/);
      if (match) {
        result.gflops = parseFloat(match[1]);
      }
    }
  });
  
  return result;
}

function parseSystemInfo(content) {
  const info = {};
  const lines = content.split('\n');
  
  lines.forEach(line => {
    if (line.includes('Model name')) {
      info.processor = line.split(':')[1].trim();
    }
    if (line.includes('CPU(s)')) {
      info.cores = line.split(':')[1].trim();
    }
  });
  
  return info;
}

// API endpoints
app.get('/api/data', (req, res) => {
  res.json(benchmarkData);
});

app.post('/api/run-benchmark', (req, res) => {
  const { type, size } = req.body;
  
  // Trigger benchmark run
  const { spawn } = require('child_process');
  const scriptPath = path.join(__dirname, '../scripts/03/run-baseline.sh');
  
  const benchmark = spawn('bash', [scriptPath]);
  
  benchmark.on('close', (code) => {
    loadBenchmarkData();
    io.emit('benchmarkComplete', { type, size, code });
    res.json({ success: true, code });
  });
  
  res.json({ success: true, message: 'Benchmark started' });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('Client connected');
  
  // Send current data to new client
  socket.emit('dataUpdate', benchmarkData);
  
  socket.on('disconnect', () => {
    console.log('Client disconnected');
  });
});

// Load initial data
loadBenchmarkData();

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Dashboard available at http://localhost:${PORT}`);
});
