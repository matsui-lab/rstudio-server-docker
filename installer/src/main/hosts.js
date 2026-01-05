const fs = require('fs').promises;
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

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

  try {
    if (process.platform === 'win32') {
      // Windows - PowerShell with elevated privileges
      const psCommand = `
        Start-Process powershell -Verb RunAs -Wait -ArgumentList '-Command', 'Add-Content -Path "${HOSTS_FILE}" -Value "${entries.replace(/\n/g, '`n')}"'
      `;
      await execPromise(`powershell -Command "${psCommand}"`);
    } else {
      // Mac/Linux - use sudo
      const command = `echo '${entries}' | sudo tee -a ${HOSTS_FILE}`;
      await execPromise(command);
    }
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      manual: `Please add the following to ${HOSTS_FILE}:\n${entries}`
    };
  }
}

module.exports = {
  checkHostsEntries,
  addHostsEntries,
};
