const express = require('express');
const path = require('path');
const os = require('os');
const docker = require('./main/docker');
const setup = require('./main/setup');
const hosts = require('./main/hosts');

const app = express();
const PORT = 3000;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'renderer')));

// Get working directory (parent of installer)
const getWorkDir = () => path.join(__dirname, '..', '..');

// API Routes

// Platform info
app.get('/api/platform', (req, res) => {
  res.json({
    platform: process.platform,
    arch: process.arch,
    homeDir: os.homedir(),
    workDir: getWorkDir(),
  });
});

// Docker checks
app.get('/api/docker/installed', async (req, res) => {
  const result = await docker.checkDockerInstalled();
  res.json(result);
});

app.get('/api/docker/running', async (req, res) => {
  const result = await docker.checkDockerRunning();
  res.json(result);
});

// Chrome OS Flex detection
app.get('/api/chromeos/detect', async (req, res) => {
  const result = await docker.detectChromeOS();
  res.json(result);
});

// Chrome OS Docker installation guide
app.get('/api/chromeos/docker-guide', (req, res) => {
  res.json({
    commands: docker.getChromeOSDockerInstallCommands(),
    steps: [
      'Open the Linux terminal',
      'Copy and paste the commands below',
      'Log out and log back in after installation',
      'Run this installer again'
    ]
  });
});

// SSH operations
app.get('/api/ssh/keys', async (req, res) => {
  const keys = await setup.checkExistingSSHKeys();
  res.json(keys);
});

app.post('/api/ssh/copy', async (req, res) => {
  const targetDir = path.join(getWorkDir(), 'ssh');
  const result = await setup.copySSHKeys(targetDir);
  res.json(result);
});

app.post('/api/ssh/generate', async (req, res) => {
  const { email } = req.body;
  const targetDir = path.join(getWorkDir(), 'ssh');
  try {
    const result = await setup.generateSSHKeys(email, targetDir);
    res.json(result);
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});

// Hosts file
app.get('/api/hosts/check', async (req, res) => {
  const instances = parseInt(req.query.instances) || 5;
  const result = await hosts.checkHostsEntries(instances);
  res.json(result);
});

app.post('/api/hosts/add', async (req, res) => {
  const { instances } = req.body;
  const result = await hosts.addHostsEntries(instances);
  res.json(result);
});

// Setup - Stream progress via Server-Sent Events
app.get('/api/setup/stream', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  // Store the response for sending events
  global.setupStream = res;

  req.on('close', () => {
    global.setupStream = null;
  });
});

function sendProgress(step, message, percent) {
  if (global.setupStream) {
    global.setupStream.write(`data: ${JSON.stringify({ step, message, percent })}\n\n`);
  }
}

function sendDockerOutput(output) {
  if (global.setupStream) {
    global.setupStream.write(`data: ${JSON.stringify({ type: 'docker', output })}\n\n`);
  }
}

app.post('/api/setup/run', async (req, res) => {
  const config = req.body;
  const workDir = getWorkDir();

  try {
    sendProgress('init', 'Initializing setup...', 0);

    // Create directories
    sendProgress('directories', 'Creating directories...', 10);
    await setup.createHomeDirectories(workDir, config.instances);

    // SSH setup
    if (config.sshOption !== 'skip') {
      sendProgress('ssh', 'Setting up SSH keys...', 20);
      const sshDir = path.join(workDir, 'ssh');
      if (config.sshOption === 'copy') {
        await setup.copySSHKeys(sshDir);
      } else if (config.sshOption === 'generate') {
        await setup.generateSSHKeys(config.sshEmail, sshDir);
      }
    }

    // GitHub auth
    if (config.githubUsername && config.githubToken) {
      sendProgress('github', 'Configuring GitHub authentication...', 30);
      await setup.setupGitHubAuth(workDir, config.instances, config.githubUsername, config.githubToken);
    }

    // Generate docker-compose.yml
    sendProgress('compose', 'Generating docker-compose.yml...', 40);
    await setup.generateComposeFile({ ...config, workDir });

    // Hosts file
    if (config.setupHosts) {
      sendProgress('hosts', 'Configuring hosts file...', 50);
      await hosts.addHostsEntries(config.instances);
    }

    // Docker build
    sendProgress('build', 'Building Docker images (this may take a while)...', 60);
    await docker.buildImage(workDir, sendDockerOutput);

    // Start containers
    sendProgress('start', 'Starting containers...', 90);
    await docker.startContainers(workDir);

    sendProgress('complete', 'Setup complete!', 100);
    res.json({ success: true });
  } catch (error) {
    sendProgress('error', error.message, -1);
    res.json({ success: false, error: error.message });
  }
});

// Shutdown server
app.post('/api/shutdown', (req, res) => {
  res.json({ success: true });
  setTimeout(() => {
    process.exit(0);
  }, 500);
});

// Start server
app.listen(PORT, async () => {
  console.log(`\n  RStudio Server Docker Installer`);
  console.log(`  ================================`);
  console.log(`  Server running at: http://localhost:${PORT}`);
  console.log(`  Opening browser...\n`);

  // Open browser
  try {
    const open = (await import('open')).default;
    await open(`http://localhost:${PORT}`);
  } catch (error) {
    console.log(`  Please open http://localhost:${PORT} in your browser`);
  }
});
