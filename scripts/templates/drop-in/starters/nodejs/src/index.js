const http = require('http');

const PORT = process.env.PORT || 8080;
const ENVIRONMENT = process.env.ENVIRONMENT || 'production';
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';

function log(level, message, data = {}) {
  if (LOG_LEVEL === 'debug' || level !== 'debug') {
    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      message,
      ...data
    }));
  }
}

const server = http.createServer((req, res) => {
  log('debug', 'Incoming request', { method: req.method, url: req.url });

  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', environment: ENVIRONMENT }));
  } else if (req.url === '/ready') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ready', environment: ENVIRONMENT }));
  } else if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      message: 'Hello from k8s-playground!',
      environment: ENVIRONMENT,
      version: '1.0.0'
    }));
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

server.listen(PORT, () => {
  log('info', `Server running on port ${PORT}`, { environment: ENVIRONMENT });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  log('info', 'SIGTERM received, shutting down gracefully');
  server.close(() => {
    log('info', 'Server closed');
    process.exit(0);
  });
});
