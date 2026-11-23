const { spawn } = require('child_process');
const path = require('path');
const http = require('http');

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForServer(url, maxAttempts = 30) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      await new Promise((resolve, reject) => {
        const req = http.get(url, (res) => {
          if (res.statusCode >= 200 && res.statusCode < 500) resolve();
          else reject(new Error(`Status ${res.statusCode}`));
        });
        req.on('error', reject);
        req.setTimeout(1000, () => {
          req.destroy();
          reject(new Error('Timeout'));
        });
      });
      return true;
    } catch (e) {
      await sleep(500);
    }
  }
  return false;
}

function runScript(scriptPath) {
  return new Promise((resolve, reject) => {
    console.log(`\n▶ Running ${path.basename(scriptPath)}...`);
    const proc = spawn('node', [scriptPath], { stdio: 'inherit' });
    proc.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`Script ${path.basename(scriptPath)} failed with exit code ${code}`));
    });
  });
}

async function main() {
  console.log('🚀 Starting backend server for tests...');
  const serverProc = spawn('node', ['-r', 'dotenv/config', 'src/server.js'], {
    cwd: path.join(__dirname, '..'),
    stdio: 'inherit',
  });

  try {
    const running = await waitForServer('http://localhost:5000/api/health');
    if (!running) {
      throw new Error('Server failed to start within timeout');
    }
    console.log('✅ Server is up and responding. Running tests...');

    await runScript(path.join(__dirname, 'authTest.js'));
    await runScript(path.join(__dirname, 'boardSharingTest.js'));
    console.log('\n✅ All backend tests completed successfully!');
  } catch (err) {
    console.error('\n❌ Backend test suite failed:', err.message);
    process.exitCode = 1;
  } finally {
    serverProc.kill();
    await sleep(500);
  }
}

main();
