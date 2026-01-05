const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  // Platform info
  getPlatform: () => ipcRenderer.invoke('get-platform'),

  // Docker operations
  checkDockerInstalled: () => ipcRenderer.invoke('check-docker-installed'),
  checkDockerRunning: () => ipcRenderer.invoke('check-docker-running'),

  // SSH operations
  checkSSHKeys: () => ipcRenderer.invoke('check-ssh-keys'),
  copySSHKeys: (targetDir) => ipcRenderer.invoke('copy-ssh-keys', targetDir),
  generateSSHKeys: (email, targetDir) => ipcRenderer.invoke('generate-ssh-keys', { email, targetDir }),

  // Hosts file
  checkHostsEntries: (instances) => ipcRenderer.invoke('check-hosts-entries', instances),

  // Setup
  runSetup: (config) => ipcRenderer.invoke('run-setup', config),

  // Progress callbacks
  onSetupProgress: (callback) => {
    ipcRenderer.on('setup-progress', (event, data) => callback(data));
  },
  onDockerOutput: (callback) => {
    ipcRenderer.on('docker-output', (event, data) => callback(data));
  },

  // Utilities
  openExternal: (url) => ipcRenderer.invoke('open-external', url),
  getResourcesPath: () => ipcRenderer.invoke('get-resources-path'),
  selectDirectory: () => ipcRenderer.invoke('select-directory'),
});
