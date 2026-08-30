// dsh-launch.js - start the DSH web server (hidden, no console window) and
// open the GUI in the default browser once the server really responds.
// ASCII-only on purpose (consistency with the other launcher files).
//
// Modes:
//   default        ensure server running (start hidden if needed), wait until
//                  it responds over HTTP, then open the browser. Used by the
//                  desktop and start-menu shortcuts.
//   --server-only  ensure server running, never open the browser. Used by the
//                  logon scheduled task.
//   --open-only    never start the server; wait until it is up, then open the
//                  browser. Used by the startup-folder shortcut (the task
//                  starts the server; this only opens the browser).
//   --port=NNNN    listen port override (testing only).
'use strict';

const { spawn, exec } = require('node:child_process');
const net = require('node:net');
const fs = require('node:fs');
const path = require('node:path');

const DEFAULT_PORT = 3080;
const WORKDIR = 'D:\\DSH';
const LOG_DIR = path.join(WORKDIR, 'logs');
const LOG_FILE = path.join(LOG_DIR, 'dsh-launch.log');
const NODE_EXE = 'D:\\Program Files\\nodejs\\node.exe';
const GLOBAL_BIN = 'C:\\Users\\xiaoy\\AppData\\Roaming\\npm\\node_modules\\@deepseek-ai\\dsh\\lib\\bin.js';
const NPX_BIN = 'C:\\Users\\xiaoy\\AppData\\Local\\npm-cache\\_npx\\1e7f6d9597241db0\\node_modules\\@deepseek-ai\\dsh\\lib\\bin.js';
// V8 module compile cache: speeds up the next cold starts of dsh.
const COMPILE_CACHE_DIR = 'C:\\Users\\xiaoy\\.dsh\\node-compile-cache';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function log(msg) {
  const ts = new Date().toISOString().replace('T', ' ').slice(0, 23);
  const line = ts + ' ' + msg;
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });
    fs.appendFileSync(LOG_FILE, line + '\n', 'utf8');
  } catch (e) { /* logging must never break the launcher */ }
  try { process.stdout.write(line + '\n'); } catch (e) { /* hidden console */ }
}

function portOpen(port, timeoutMs) {
  const t = timeoutMs || 600;
  return new Promise((resolve) => {
    const s = net.connect({ host: '127.0.0.1', port });
    let done = false;
    const fin = (ok) => {
      if (done) return;
      done = true;
      try { s.destroy(); } catch (e) { /* noop */ }
      resolve(ok);
    };
    s.setTimeout(t, () => fin(false));
    s.on('connect', () => fin(true));
    s.on('error', () => fin(false));
  });
}

// True only when an HTTP response with a 2xx/3xx status is received.
function httpReady(port, timeoutMs) {
  const t = timeoutMs || 1500;
  return new Promise((resolve) => {
    const s = net.connect({ host: '127.0.0.1', port });
    let done = false;
    let data = '';
    const fin = (ok) => {
      if (done) return;
      done = true;
      try { s.destroy(); } catch (e) { /* noop */ }
      resolve(ok);
    };
    s.setTimeout(t, () => fin(false));
    s.on('connect', () => {
      s.write('GET / HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n');
    });
    s.on('data', (c) => { data += c.toString('latin1'); });
    s.on('end', () => {
      const m = /^HTTP\/1\.[01]\s+(\d{3})/m.exec(data);
      fin(!!m && /^[23]\d\d$/.test(m[1]));
    });
    s.on('error', () => fin(false));
  });
}

function resolveBin() {
  for (const p of [GLOBAL_BIN, NPX_BIN]) {
    try { fs.accessSync(p); return p; } catch (e) { /* try next */ }
  }
  return null;
}

function spawnServer(port) {
  const bin = resolveBin();
  if (!bin) {
    log('dsh-launch: ERROR no dsh bin.js found (checked global and npx cache)');
    return null;
  }
  const args = [bin, '--profile', 'web', '--no-open'];
  if (port !== DEFAULT_PORT) args.push('--port', String(port));
  let outFd = 'ignore';
  let errFd = 'ignore';
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });
    outFd = fs.openSync(path.join(LOG_DIR, 'dsh-server.out.log'), 'a');
    errFd = fs.openSync(path.join(LOG_DIR, 'dsh-server.err.log'), 'a');
  } catch (e) { /* logs optional */ }
  const child = spawn(NODE_EXE, args, {
    cwd: WORKDIR,
    detached: true,
    windowsHide: true,
    stdio: ['ignore', outFd, errFd],
    env: Object.assign({}, process.env, { NODE_COMPILE_CACHE: COMPILE_CACHE_DIR }),
  });
  child.unref();
  log('dsh-launch: spawned dsh (' + bin + ') pid=' + child.pid);
  child.on('error', (e) => log('dsh-launch: spawn error: ' + e.message));
  return child;
}

function openBrowser(url) {
  return new Promise((resolve) => {
    exec('start "" "' + url + '"', { windowsHide: true }, (err) => {
      if (err) {
        log('dsh-launch: open browser failed: ' + err.message);
        resolve(false);
      } else {
        log('dsh-launch: browser open requested: ' + url);
        resolve(true);
      }
    });
  });
}

async function main() {
  const t0 = Date.now();
  const argv = process.argv.slice(2);
  const serverOnly = argv.indexOf('--server-only') !== -1;
  const openOnly = argv.indexOf('--open-only') !== -1;
  const portArg = argv.find((a) => a.indexOf('--port=') === 0);
  const port = portArg ? Number(portArg.split('=')[1]) : DEFAULT_PORT;
  const url = 'http://127.0.0.1:' + port;

  log('dsh-launch: start (port=' + port + ' serverOnly=' + serverOnly + ' openOnly=' + openOnly + ')');

  if (await portOpen(port)) {
    log('dsh-launch: server already running on port ' + port);
  } else if (openOnly) {
    // Prefer the server started by the logon Run-key entry; if it is not up
    // within ~12s, fall back to starting it ourselves so the startup-folder
    // entry stays self-sufficient.
    log('dsh-launch: open-only mode, waiting for server on port ' + port);
    let ready = false;
    for (let i = 0; i < 48; i++) {
      await sleep(250);
      if (await httpReady(port)) { ready = true; break; }
    }
    if (!ready) {
      log('dsh-launch: open-only: server not up after 12s, starting it as fallback');
      const child = spawnServer(port);
      for (let i = 0; i < 192; i++) {
        await sleep(250);
        if (await httpReady(port)) { ready = true; break; }
        if (child && child.exitCode !== null) {
          log('dsh-launch: server process exited early (code ' + child.exitCode + ')');
          break;
        }
      }
      if (ready) log('dsh-launch: server ready after fallback start');
    }
  } else {
    log('dsh-launch: server not running, starting dsh web --no-open');
    const child = spawnServer(port);
    const tWait = Date.now();
    let ready = false;
    for (let i = 0; i < 240; i++) {
      await sleep(250);
      if (await httpReady(port)) { ready = true; break; }
      if (child && child.exitCode !== null) {
        log('dsh-launch: server process exited early (code ' + child.exitCode + ')');
        break;
      }
    }
    if (ready) {
      log('dsh-launch: server ready after ' + ((Date.now() - tWait) / 1000).toFixed(1) + 's');
    } else {
      log('dsh-launch: server did not become ready in time');
    }
  }

  if (!serverOnly) {
    await openBrowser(url);
  }
  log('dsh-launch: done in ' + ((Date.now() - t0) / 1000).toFixed(1) + 's');
}

main().catch((e) => {
  try { log('dsh-launch: fatal: ' + ((e && e.stack) || e)); } catch (err) { /* noop */ }
});
