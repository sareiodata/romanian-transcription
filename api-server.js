#!/usr/bin/env node
'use strict';
// Serialize API requests, loading a private backend only while a request runs.
const http = require('http');
const net = require('net');
const path = require('path');
const {spawn} = require('child_process');
const {setTimeout: delay} = require('timers/promises');
const ROOT = __dirname;
const runtime = require('./runtime').selectRuntime();
const HOST = process.env.TRANSCRIPT_API_HOST || '127.0.0.1';
const PORT = Number(process.env.TRANSCRIPT_API_PORT || 8322);
let stopping = false, activeChild = null, pending = Promise.resolve();

async function freePort() {
  const probe = net.createServer();
  await new Promise((resolve, reject) => { probe.once('error', reject); probe.listen(0, '127.0.0.1', resolve); });
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  return port;
}
function connectable(port) {
  return new Promise(resolve => {
    const socket = net.connect(port, '127.0.0.1');
    const finish = ok => { socket.destroy(); resolve(ok); };
    socket.setTimeout(300);
    socket.once('connect', () => finish(true));
    socket.once('error', () => finish(false));
    socket.once('timeout', () => finish(false));
  });
}
async function serve(req, res) {
  if (stopping || res.destroyed) return;
  let child, exited, killTimer, upstream;
  const cancel = () => { upstream?.destroy(); child?.kill('SIGTERM'); };
  res.once('close', cancel);
  try {
    const port = await freePort();
    if (stopping || res.destroyed) return;
    const args = ['--server', '--host', '127.0.0.1', '--port', String(port),
      ...runtime.args, '--threads', '6', '--beam-size', '1',
      '--backend', 'canary', '--model', path.resolve(ROOT, 'models', process.env.TRANSCRIPT_MODEL || 'canary-1b-v2-q8_0.gguf'),
      '--language', 'ro', '--source-lang', 'ro', '--target-lang', 'ro', '--no-auto-aligner'];
    child = activeChild = spawn(runtime.binary, args, {
      cwd: ROOT, env: runtime.env,
      stdio: ['ignore', 'ignore', 'pipe']
    });
    let ended = false, failure, diagnostic = '';
    exited = new Promise(resolve => {
      child.once('error', error => { failure = error; ended = true; resolve(); });
      child.once('close', code => { ended = true; failure ||= new Error(`Backend exited (${code}): ${diagnostic}`); resolve(); });
    });
    child.stderr.on('data', data => { diagnostic = (diagnostic + data).slice(-12000); process.stderr.write(data); });
    const deadline = Date.now() + 180000;
    while (!(await connectable(port))) {
      if (ended) throw failure;
      if (stopping || res.destroyed) throw new Error('Request cancelled');
      if (Date.now() > deadline) throw new Error('Backend startup timed out');
      await delay(100);
    }
    if (stopping || res.destroyed) throw new Error('Request cancelled');
    await new Promise((resolve, reject) => {
      res.once('close', resolve);
      upstream = http.request({hostname: '127.0.0.1', port, method: req.method, path: req.url,
        headers: {...req.headers, host: `127.0.0.1:${port}`, connection: 'close'}}, response => {
        res.writeHead(response.statusCode, response.headers);
        response.once('error', reject);
        response.pipe(res);
        res.once('finish', resolve);
      });
      upstream.once('error', reject);
      req.once('error', reject);
      req.pipe(upstream);
    });
  } catch (error) {
    if (!res.destroyed && !res.headersSent) {
      res.writeHead(502, {'Content-Type': 'application/json'});
      res.end(JSON.stringify({error: error.message}));
    } else if (!res.destroyed) res.destroy();
  } finally {
    res.removeListener('close', cancel);
    upstream?.destroy();
    if (child) {
      child.kill('SIGTERM');
      killTimer = setTimeout(() => child.kill('SIGKILL'), 1500);
      await exited;
      clearTimeout(killTimer);
      activeChild = null;
    }
  }
}
const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, {'Content-Type': 'application/json'});
    return res.end(JSON.stringify({status: 'ok', mode: 'on-demand', device: runtime.label}));
  }
  pending = pending.then(() => serve(req, res)).catch(error => console.error(error));
});
server.requestTimeout = 0;
server.listen(PORT, HOST, () => console.log(`On-demand transcription API listening on ${HOST}:${PORT}`));
async function shutdown() {
  if (stopping) return;
  stopping = true;
  server.close();
  server.closeAllConnections();
  activeChild?.kill('SIGTERM');
  const timer = setTimeout(() => activeChild?.kill('SIGKILL'), 1500);
  await pending;
  clearTimeout(timer);
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
