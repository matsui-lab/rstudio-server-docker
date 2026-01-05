const fs = require('fs').promises;
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);
const sudo = require('sudo-prompt');

const HOSTS_FILE = process.platform === 'win32'
  ? 'C:\\Windows\\System32\\drivers\\etc\\hosts'
  : '/etc/hosts';

async function checkHostsEntries(instances) {
  try {
    const content = await fs.readFile(HOSTS_FILE, 'utf-8');
    const missing = [];

    for (let i = 1; i <= instances; i++) {
      const letter = String.fromCharCode(96 + i);
      const hostname = `rstudio-${letter}`;
      const pattern = new RegExp(`^127\\.0\\.0\\.1\\s+${hostname}$`, 'm');

      if (!pattern.test(content)) {
        missing.push(hostname);
      }
    }

    return { allPresent: missing.length === 0, missing };
  } catch (error) {
    return { allPresent: false, missing: [], error: error.message };
  }
}

async function addHostsEntries(instances) {
  const { missing } = await checkHostsEntries(instances);

  if (missing.length === 0) {
    return { success: true, message: 'All entries already exist' };
  }

  const entries = missing.map(hostname => `127.0.0.1 ${hostname}`).join('\n');

  if (process.platform === 'win32') {
    return addHostsEntriesWindows(entries);
  } else if (process.platform === 'darwin') {
    return addHostsEntriesMac(entries);
  } else {
    return addHostsEntriesLinux(entries);
  }
}

async function addHostsEntriesWindows(entries) {
  return new Promise((resolve) => {
    const command = `powershell -Command "Add-Content -Path '${HOSTS_FILE}' -Value '${entries.replace(/\n/g, '`n')}'"`;

    sudo.exec(command, { name: 'RStudio Server Docker Installer' }, (error) => {
      if (error) {
        resolve({ success: false, error: error.message });
      } else {
        resolve({ success: true });
      }
    });
  });
}

async function addHostsEntriesMac(entries) {
  return new Promise((resolve) => {
    const command = `echo "${entries}" | sudo tee -a ${HOSTS_FILE}`;

    sudo.exec(command, { name: 'RStudio Server Docker Installer' }, (error) => {
      if (error) {
        resolve({ success: false, error: error.message });
      } else {
        resolve({ success: true });
      }
    });
  });
}

async function addHostsEntriesLinux(entries) {
  return new Promise((resolve) => {
    const command = `echo "${entries}" | tee -a ${HOSTS_FILE}`;

    sudo.exec(command, { name: 'RStudio Server Docker Installer' }, (error) => {
      if (error) {
        resolve({ success: false, error: error.message });
      } else {
        resolve({ success: true });
      }
    });
  });
}

module.exports = {
  checkHostsEntries,
  addHostsEntries,
};
