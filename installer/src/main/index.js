const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path = require('path');
const docker = require('./docker');
const setup = require('./setup');
const hosts = require('./hosts');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    minWidth: 600,
    minHeight: 500,
    webPreferences: {
      preload: path.join(__dirname, '..', 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
    titleBarStyle: 'hiddenInset',
    show: false,
  });

  mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'));

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // Open external links in browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// IPC Handlers

// Docker checks
ipcMain.handle('check-docker-installed', async () => {
  return await docker.checkDockerInstalled();
});

ipcMain.handle('check-docker-running', async () => {
  return await docker.checkDockerRunning();
});

// Platform info
ipcMain.handle('get-platform', () => {
  return {
    platform: process.platform,
    arch: process.arch,
  };
});

// SSH operations
ipcMain.handle('check-ssh-keys', async () => {
  return await setup.checkExistingSSHKeys();
});

ipcMain.handle('copy-ssh-keys', async (event, targetDir) => {
  return await setup.copySSHKeys(targetDir);
});

ipcMain.handle('generate-ssh-keys', async (event, { email, targetDir }) => {
  return await setup.generateSSHKeys(email, targetDir);
});

// Setup operations
ipcMain.handle('run-setup', async (event, config) => {
  const sendProgress = (step, message, percent) => {
    mainWindow.webContents.send('setup-progress', { step, message, percent });
  };

  try {
    sendProgress('init', 'Initializing setup...', 0);

    // Create directories
    sendProgress('directories', 'Creating directories...', 10);
    await setup.createHomeDirectories(config.workDir, config.instances);

    // SSH setup
    if (config.sshOption !== 'skip') {
      sendProgress('ssh', 'Setting up SSH keys...', 20);
      if (config.sshOption === 'copy') {
        await setup.copySSHKeys(path.join(config.workDir, 'ssh'));
      } else if (config.sshOption === 'generate') {
        await setup.generateSSHKeys(config.sshEmail, path.join(config.workDir, 'ssh'));
      }
    }

    // GitHub auth
    if (config.githubUsername && config.githubToken) {
      sendProgress('github', 'Configuring GitHub authentication...', 30);
      await setup.setupGitHubAuth(config.workDir, config.instances, config.githubUsername, config.githubToken);
    }

    // Generate docker-compose.yml
    sendProgress('compose', 'Generating docker-compose.yml...', 40);
    await setup.generateComposeFile(config);

    // Hosts file
    if (config.setupHosts) {
      sendProgress('hosts', 'Configuring hosts file...', 50);
      await hosts.addHostsEntries(config.instances);
    }

    // Docker build
    sendProgress('build', 'Building Docker images (this may take a while)...', 60);
    await docker.buildImage(config.workDir, (output) => {
      mainWindow.webContents.send('docker-output', output);
    });

    // Start containers
    sendProgress('start', 'Starting containers...', 90);
    await docker.startContainers(config.workDir);

    sendProgress('complete', 'Setup complete!', 100);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

// Hosts file
ipcMain.handle('check-hosts-entries', async (event, instances) => {
  return await hosts.checkHostsEntries(instances);
});

// Open external URL
ipcMain.handle('open-external', async (event, url) => {
  await shell.openExternal(url);
});

// Get app resources path
ipcMain.handle('get-resources-path', () => {
  if (app.isPackaged) {
    return process.resourcesPath;
  }
  return path.join(__dirname, '..', '..', '..');
});

// Select directory
ipcMain.handle('select-directory', async () => {
  const { dialog } = require('electron');
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openDirectory', 'createDirectory'],
  });
  return result.canceled ? null : result.filePaths[0];
});
