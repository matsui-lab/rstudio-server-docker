const { exec, spawn } = require('child_process');
const util = require('util');
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

module.exports = {
  checkDockerInstalled,
  checkDockerRunning,
  buildImage,
  startContainers,
  stopContainers,
  getContainerStatus,
};
