const app = {
  currentStep: 0,
  steps: ['welcome', 'docker', 'config', 'ssh', 'github', 'hosts', 'progress', 'complete'],
  config: {
    workDir: '',
    instances: 5,
    basePort: 8787,
    shareClaudeConfig: true,
    includeRunner: true,
    sshOption: 'copy',
    sshEmail: '',
    githubUsername: '',
    githubToken: '',
    setupHosts: true,
  },

  async init() {
    // Set default work directory
    const resourcesPath = await window.api.getResourcesPath();
    this.config.workDir = resourcesPath;
    document.getElementById('work-dir').value = resourcesPath;

    // Setup SSH option change handler
    document.querySelectorAll('input[name="ssh-option"]').forEach(radio => {
      radio.addEventListener('change', (e) => {
        const emailGroup = document.getElementById('ssh-email-group');
        emailGroup.style.display = e.target.value === 'generate' ? 'block' : 'none';
        this.config.sshOption = e.target.value;
      });
    });

    // Check for existing SSH keys
    const keys = await window.api.checkSSHKeys();
    if (keys.length > 0) {
      document.getElementById('ssh-key-status').style.display = 'block';
      document.getElementById('ssh-key-status').innerHTML =
        `Found existing keys: ${keys.map(k => k.type).join(', ')}`;
    }

    // Setup progress listeners
    window.api.onSetupProgress((data) => {
      document.getElementById('progress-fill').style.width = `${data.percent}%`;
      document.getElementById('progress-message').textContent = data.message;
    });

    window.api.onDockerOutput((output) => {
      const log = document.getElementById('docker-log');
      log.textContent += output;
      log.scrollTop = log.scrollHeight;
    });
  },

  showStep(stepIndex) {
    // Update pages
    document.querySelectorAll('.page').forEach((page, i) => {
      page.classList.toggle('active', i === stepIndex);
    });

    // Update sidebar
    document.querySelectorAll('.step').forEach((step, i) => {
      step.classList.remove('active');
      if (i < stepIndex) {
        step.classList.add('completed');
      } else if (i === stepIndex) {
        step.classList.add('active');
      } else {
        step.classList.remove('completed');
      }
    });

    this.currentStep = stepIndex;

    // Run step-specific logic
    const stepName = this.steps[stepIndex];
    if (stepName === 'docker') {
      this.checkDocker();
    } else if (stepName === 'hosts') {
      this.updateHostsPreview();
    }
  },

  nextStep() {
    this.saveCurrentStepData();
    if (this.currentStep < this.steps.length - 1) {
      this.showStep(this.currentStep + 1);
    }
  },

  prevStep() {
    if (this.currentStep > 0) {
      this.showStep(this.currentStep - 1);
    }
  },

  saveCurrentStepData() {
    const step = this.steps[this.currentStep];

    if (step === 'config') {
      this.config.instances = parseInt(document.getElementById('instances').value);
      this.config.basePort = parseInt(document.getElementById('base-port').value);
      this.config.shareClaudeConfig = document.getElementById('share-claude').checked;
      this.config.includeRunner = document.getElementById('include-runner').checked;
    } else if (step === 'ssh') {
      this.config.sshOption = document.querySelector('input[name="ssh-option"]:checked').value;
      this.config.sshEmail = document.getElementById('ssh-email').value;
    } else if (step === 'github') {
      this.config.githubUsername = document.getElementById('github-username').value;
      this.config.githubToken = document.getElementById('github-token').value;
    } else if (step === 'hosts') {
      this.config.setupHosts = document.getElementById('setup-hosts').checked;
    }
  },

  async checkDocker() {
    const installedCheck = document.getElementById('check-docker-installed');
    const runningCheck = document.getElementById('check-docker-running');
    const errorBox = document.getElementById('docker-error');
    const nextBtn = document.getElementById('docker-next');

    // Check installed
    installedCheck.querySelector('.check-icon').textContent = '⏳';
    installedCheck.classList.remove('success', 'error');

    const installed = await window.api.checkDockerInstalled();

    if (installed.installed) {
      installedCheck.querySelector('.check-icon').textContent = '✓';
      installedCheck.classList.add('success');

      // Check running
      runningCheck.querySelector('.check-icon').textContent = '⏳';
      const running = await window.api.checkDockerRunning();

      if (running.running) {
        runningCheck.querySelector('.check-icon').textContent = '✓';
        runningCheck.classList.add('success');
        errorBox.style.display = 'none';
        nextBtn.disabled = false;
      } else {
        runningCheck.querySelector('.check-icon').textContent = '✗';
        runningCheck.classList.add('error');
        errorBox.style.display = 'block';
        errorBox.querySelector('p').textContent = 'Docker is not running. Please start Docker Desktop.';
        nextBtn.disabled = true;
      }
    } else {
      installedCheck.querySelector('.check-icon').textContent = '✗';
      installedCheck.classList.add('error');
      runningCheck.querySelector('.check-icon').textContent = '—';
      errorBox.style.display = 'block';
      nextBtn.disabled = true;
    }
  },

  async selectDirectory() {
    const dir = await window.api.selectDirectory();
    if (dir) {
      this.config.workDir = dir;
      document.getElementById('work-dir').value = dir;
    }
  },

  updateHostsPreview() {
    const instances = parseInt(document.getElementById('instances').value);
    let preview = '';
    for (let i = 1; i <= instances; i++) {
      const letter = String.fromCharCode(96 + i);
      preview += `127.0.0.1 rstudio-${letter}\n`;
    }
    document.getElementById('hosts-preview').textContent = preview;
  },

  async startSetup() {
    this.saveCurrentStepData();
    this.showStep(this.steps.indexOf('progress'));

    const result = await window.api.runSetup(this.config);

    if (result.success) {
      this.showStep(this.steps.indexOf('complete'));
      this.showAccessList();
    } else {
      document.getElementById('progress-message').textContent = `Error: ${result.error}`;
      document.getElementById('progress-message').style.color = 'var(--error)';
    }
  },

  showAccessList() {
    const list = document.getElementById('access-list');
    let html = '';

    for (let i = 1; i <= this.config.instances; i++) {
      const letter = String.fromCharCode(96 + i);
      const port = this.config.basePort + i - 1;
      html += `
        <div class="access-item">
          <div>
            <strong>Instance ${letter.toUpperCase()}</strong><br>
            <small>User: rstudio_${letter} / Pass: rstudio_${letter}</small>
          </div>
          <a href="#" onclick="api.openExternal('http://rstudio-${letter}:${port}')">
            http://rstudio-${letter}:${port}
          </a>
        </div>
      `;
    }

    list.innerHTML = html;
  },

  openFirstInstance() {
    const port = this.config.basePort;
    window.api.openExternal(`http://rstudio-a:${port}`);
  },
};

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
  app.init();
});
