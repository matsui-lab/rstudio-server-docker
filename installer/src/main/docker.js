const { exec, spawn } = require('child_process');
const util = require('util');
const fs = require('fs').promises;
const execPromise = util.promisify(exec);

async function checkDockerInstalled() {
  try {
    await execPromise('docker --version');
    return { installed: true };
  } catch (error) {
    return { installed: false, error: 'Docker is not installed' };
  }
}

async function checkDockerRunning() {
  try {
    await execPromise('docker info');
    return { running: true };
  } catch (error) {
    return { running: false, error: 'Docker daemon is not running' };
  }
}

async function buildImage(workDir, onOutput) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', ['compose', 'build'], {
      cwd: workDir,
      shell: true,
    });

    child.stdout.on('data', (data) => {
      if (onOutput) onOutput(data.toString());
    });

    child.stderr.on('data', (data) => {
      if (onOutput) onOutput(data.toString());
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Docker build failed with code ${code}`));
      }
    });

    child.on('error', (error) => {
      reject(error);
    });
  });
}

async function startContainers(workDir) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', ['compose', 'up', '-d'], {
      cwd: workDir,
      shell: true,
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Docker compose up failed with code ${code}`));
      }
    });

    child.on('error', (error) => {
      reject(error);
    });
  });
}

async function stopContainers(workDir) {
  try {
    await execPromise('docker compose down', { cwd: workDir });
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function getContainerStatus(workDir) {
  try {
    const { stdout } = await execPromise('docker compose ps --format json', { cwd: workDir });
    return JSON.parse(stdout);
  } catch (error) {
    return [];
  }
}

// Chrome OS Flex / Crostini detection
async function detectChromeOS() {
  try {
    // Check for Crostini mount point
    await fs.access('/mnt/chromeos');
    return { isChromeOS: true, inCrostini: true };
  } catch {
    // Also check /etc/os-release for Chrome OS
    try {
      const osRelease = await fs.readFile('/etc/os-release', 'utf-8');
      if (osRelease.includes('Chrome OS')) {
        return { isChromeOS: true, inCrostini: false };
      }
    } catch {}
    return { isChromeOS: false, inCrostini: false };
  }
}

// Chrome OS Docker installation commands
function getChromeOSDockerInstallCommands() {
  return `# Install prerequisites
sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# IMPORTANT: Log out and log back in for the group membership to take effect`;
}

module.exports = {
  checkDockerInstalled,
  checkDockerRunning,
  buildImage,
  startContainers,
  stopContainers,
  getContainerStatus,
  detectChromeOS,
  getChromeOSDockerInstallCommands,
};
