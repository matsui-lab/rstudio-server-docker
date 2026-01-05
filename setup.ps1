# RStudio Server Docker Setup for Windows
# Run in PowerShell: .\setup.ps1

$ErrorActionPreference = "Stop"

function Write-Header {
    Write-Host "======================================" -ForegroundColor Blue
    Write-Host "  RStudio Server Docker Setup" -ForegroundColor Blue
    Write-Host "======================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-Success {
    param($Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param($Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error {
    param($Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# Detect platform
function Get-DockerPlatform {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
    switch ($arch) {
        "X64" { $script:DockerPlatform = "linux/amd64" }
        "Arm64" { $script:DockerPlatform = "linux/arm64" }
        default {
            Write-Warning "Unknown architecture: $arch. Defaulting to linux/amd64"
            $script:DockerPlatform = "linux/amd64"
        }
    }
    Write-Success "Detected platform: $script:DockerPlatform"
}

# Check Docker installation
function Test-Docker {
    try {
        $null = Get-Command docker -ErrorAction Stop
    }
    catch {
        Write-Error "Docker is not installed. Please install Docker Desktop for Windows."
        Write-Host "  https://docs.docker.com/desktop/install/windows-install/"
        exit 1
    }

    try {
        $null = docker info 2>$null
    }
    catch {
        Write-Error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    }

    Write-Success "Docker is installed and running"

    try {
        $null = docker compose version 2>$null
    }
    catch {
        Write-Error "Docker Compose is not available."
        exit 1
    }
    Write-Success "Docker Compose is available"
}

# Get user input
function Get-Config {
    Write-Host ""
    Write-Host "--- Configuration ---" -ForegroundColor Blue
    Write-Host ""

    # Number of instances
    $input = Read-Host "Number of RStudio instances [1-10, default: 5]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = "5" }
    $script:Instances = [int]$input
    if ($script:Instances -lt 1 -or $script:Instances -gt 10) {
        Write-Warning "Invalid number. Using default: 5"
        $script:Instances = 5
    }

    # Base port
    $input = Read-Host "Base port [default: 8787]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = "8787" }
    $script:BasePort = [int]$input

    # SSH key handling
    Write-Host ""
    Write-Host "SSH key options:"
    Write-Host "  1) Copy existing keys from ~/.ssh"
    Write-Host "  2) Generate new SSH key pair"
    Write-Host "  3) Skip SSH setup"
    $input = Read-Host "Choose [1-3, default: 1]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = "1" }
    $script:SshOption = $input

    # Claude config sharing
    Write-Host ""
    $input = Read-Host "Share Claude config from host ~/.claude? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = "Y" }
    $script:ShareClaudeConfig = $input -match "^[Yy]"

    # Include runner
    $input = Read-Host "Include runner container for batch processing? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = "Y" }
    $script:IncludeRunner = $input -match "^[Yy]"

    # GitHub PAT setup
    Write-Host ""
    Write-Host "--- GitHub Authentication ---" -ForegroundColor Blue
    Write-Host "A Personal Access Token (PAT) enables git/gh commands in containers."
    Write-Host "Create one at: https://github.com/settings/tokens"
    Write-Host "Required scopes: repo, read:org, workflow"
    Write-Host ""
    $input = Read-Host "Setup GitHub PAT? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = "Y" }

    if ($input -match "^[Yy]") {
        $script:GitHubUsername = Read-Host "GitHub username"
        $secureToken = Read-Host "GitHub PAT (input hidden)" -AsSecureString
        $script:GitHubToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken))
        $script:SetupGitHubAuth = $true
    }
    else {
        $script:GitHubUsername = ""
        $script:GitHubToken = ""
        $script:SetupGitHubAuth = $false
    }
}

# Setup SSH keys
function Initialize-Ssh {
    $sshDir = Join-Path $PSScriptRoot "ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir | Out-Null
    }

    switch ($script:SshOption) {
        "1" {
            $userSshDir = Join-Path $env:USERPROFILE ".ssh"
            $ed25519Key = Join-Path $userSshDir "id_ed25519"
            $rsaKey = Join-Path $userSshDir "id_rsa"

            if (Test-Path $ed25519Key) {
                Copy-Item "$ed25519Key" "$sshDir/"
                Copy-Item "${ed25519Key}.pub" "$sshDir/"
                Write-Success "Copied existing SSH keys (ed25519)"
            }
            elseif (Test-Path $rsaKey) {
                Copy-Item "$rsaKey" "$sshDir/"
                Copy-Item "${rsaKey}.pub" "$sshDir/"
                Write-Success "Copied existing SSH keys (RSA)"
            }
            else {
                Write-Warning "No existing SSH keys found. Generating new ones..."
                $script:SshOption = "2"
            }
        }
        "3" {
            Write-Warning "Skipping SSH setup. Git over SSH will not work."
            return
        }
    }

    if ($script:SshOption -eq "2") {
        $email = Read-Host "Enter email for SSH key"
        $keyPath = Join-Path $sshDir "id_ed25519"
        ssh-keygen -t ed25519 -C $email -f $keyPath -N '""'
        Write-Success "Generated new SSH key pair"
        Write-Host ""
        Write-Host "Add this public key to your GitHub account:" -ForegroundColor Yellow
        Get-Content "${keyPath}.pub"
        Write-Host ""
    }

    # Create SSH config
    $configContent = @"
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
"@
    Set-Content -Path (Join-Path $sshDir "config") -Value $configContent
}

# Create home directories
function New-HomeDirs {
    for ($i = 1; $i -le $script:Instances; $i++) {
        $letter = [char](96 + $i)
        $homeDir = Join-Path $PSScriptRoot "home_$letter"
        $rstudioConfigDir = Join-Path $homeDir ".config/rstudio"

        if (-not (Test-Path $rstudioConfigDir)) {
            New-Item -ItemType Directory -Path $rstudioConfigDir -Force | Out-Null
        }

        $prefsSource = Join-Path $PSScriptRoot "config/rstudio-prefs.json"
        Copy-Item $prefsSource (Join-Path $rstudioConfigDir "rstudio-prefs.json")
    }
    Write-Success "Created home directories for $($script:Instances) instances"
}

# Setup GitHub authentication (git credentials + gh)
function Initialize-GitHubAuth {
    if (-not $script:SetupGitHubAuth) {
        return
    }

    for ($i = 1; $i -le $script:Instances; $i++) {
        $letter = [char](96 + $i)
        $homeDir = Join-Path $PSScriptRoot "home_$letter"

        # Create .git-credentials file
        $credentialsPath = Join-Path $homeDir ".git-credentials"
        "https://$($script:GitHubUsername):$($script:GitHubToken)@github.com" | Set-Content $credentialsPath

        # Create .gitconfig with credential helper
        $gitconfigPath = Join-Path $homeDir ".gitconfig"
        $gitconfigContent = @"
[user]
    name = $($script:GitHubUsername)
    email = $($script:GitHubUsername)@users.noreply.github.com
[credential]
    helper = store
[init]
    defaultBranch = main
"@
        Set-Content -Path $gitconfigPath -Value $gitconfigContent

        # Create gh config directory and hosts.yml for gh CLI
        $ghConfigDir = Join-Path $homeDir ".config/gh"
        if (-not (Test-Path $ghConfigDir)) {
            New-Item -ItemType Directory -Path $ghConfigDir -Force | Out-Null
        }

        $ghHostsPath = Join-Path $ghConfigDir "hosts.yml"
        $ghHostsContent = @"
github.com:
    oauth_token: $($script:GitHubToken)
    user: $($script:GitHubUsername)
    git_protocol: https
"@
        Set-Content -Path $ghHostsPath -Value $ghHostsContent
    }

    Write-Success "Configured GitHub authentication for all instances"
}

# Generate docker-compose.yml
function New-ComposeFile {
    $compose = @"
# Auto-generated by setup.ps1
# Instances: $($script:Instances), Platform: $($script:DockerPlatform)

services:

"@

    for ($i = 1; $i -le $script:Instances; $i++) {
        $letter = [char](96 + $i)
        $port = $script:BasePort + $i - 1

        $service = @"
  rstudio_$letter`:
    build: .
    container_name: rstudio-server-$letter
    hostname: rstudio-$letter
    platform: $($script:DockerPlatform)
    ports: ["${port}:8787"]
    environment:
      USER: rstudio_$letter
      PASSWORD: rstudio_$letter
      RETICULATE_PYTHON: /opt/venv/bin/python
      RENV_PATHS_CACHE: /opt/renv/cache
      RENV_PATHS_LIBRARY: /opt/renv/library
    volumes:
      - ./home_$letter`:/home/rstudio_$letter
      - ./ssh:/home/rstudio_$letter/.ssh:ro

"@
        if ($script:ShareClaudeConfig) {
            $service += "      - ~/.claude:/home/rstudio_$letter/.claude`n"
        }

        $service += @"
      - renv-cache:/opt/renv/cache
      - renv-lib:/opt/renv/library
    working_dir: /home/rstudio_$letter
    restart: unless-stopped


"@
        $compose += $service
    }

    if ($script:IncludeRunner) {
        $runner = @"
  runner:
    build: .
    container_name: rstudio-runner
    hostname: rstudio-runner
    platform: $($script:DockerPlatform)
    environment:
      RETICULATE_PYTHON: /opt/venv/bin/python
      RENV_PATHS_CACHE: /opt/renv/cache
      RENV_PATHS_LIBRARY: /opt/renv/library
    volumes:

"@
        for ($i = 1; $i -le $script:Instances; $i++) {
            $letter = [char](96 + $i)
            $runner += "      - ./home_$letter`:/home/rstudio_$letter`n"
        }

        if ($script:ShareClaudeConfig) {
            $runner += "      - ~/.claude:/home/rstudio/.claude`n"
        }

        $runner += @"
      - renv-cache:/opt/renv/cache
      - renv-lib:/opt/renv/library
    working_dir: /home
    entrypoint: ["bash", "-lc"]
    tty: true
    restart: unless-stopped


"@
        $compose += $runner
    }

    $compose += @"
volumes:
  renv-cache:
  renv-lib:
"@

    Set-Content -Path (Join-Path $PSScriptRoot "docker-compose.yml") -Value $compose
    Write-Success "Generated docker-compose.yml"
}

# Save configuration to .env
function Save-EnvFile {
    $envContent = @"
# Generated configuration
RSTUDIO_INSTANCES=$($script:Instances)
RSTUDIO_BASE_PORT=$($script:BasePort)
SHARE_CLAUDE_CONFIG=$($script:ShareClaudeConfig.ToString().ToLower())
INCLUDE_RUNNER=$($script:IncludeRunner.ToString().ToLower())
DOCKER_PLATFORM=$($script:DockerPlatform)
"@
    Set-Content -Path (Join-Path $PSScriptRoot ".env") -Value $envContent
    Write-Success "Saved configuration to .env"
}

# Setup hosts file entries for session isolation
function Initialize-HostsFile {
    Write-Host ""
    Write-Host "--- Hosts File Setup ---" -ForegroundColor Blue
    Write-Host "Adding hostname entries to hosts file enables independent sessions."
    Write-Host "This requires Administrator privileges."
    Write-Host ""

    $input = Read-Host "Add entries to hosts file? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = "Y" }

    if ($input -notmatch "^[Yy]") {
        Write-Warning "Skipping hosts file setup."
        Write-Host "You can manually add the following entries to C:\Windows\System32\drivers\etc\hosts:"
        for ($i = 1; $i -le $script:Instances; $i++) {
            $letter = [char](96 + $i)
            Write-Host "  127.0.0.1 rstudio-$letter"
        }
        return
    }

    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue

    $entriesToAdd = @()
    for ($i = 1; $i -le $script:Instances; $i++) {
        $letter = [char](96 + $i)
        $hostname = "rstudio-$letter"
        $pattern = "^127\.0\.0\.1\s+$hostname`$"
        if (-not ($hostsContent | Where-Object { $_ -match $pattern })) {
            $entriesToAdd += "127.0.0.1 $hostname"
        }
    }

    if ($entriesToAdd.Count -eq 0) {
        Write-Success "All hostname entries already exist in hosts file"
        return
    }

    Write-Host ""
    Write-Host "The following entries will be added to hosts file:"
    $entriesToAdd | ForEach-Object { Write-Host "  $_" }
    Write-Host ""

    # Check if running as Administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Warning "Administrator privileges required. Please run this command in an elevated PowerShell:"
        Write-Host ""
        $entries = $entriesToAdd -join "`n"
        Write-Host "Add-Content -Path '$hostsPath' -Value @'"
        Write-Host $entries
        Write-Host "'@"
        return
    }

    try {
        Add-Content -Path $hostsPath -Value ($entriesToAdd -join "`n")
        Write-Success "Added hostname entries to hosts file"
    }
    catch {
        Write-Error "Failed to update hosts file: $_"
        Write-Host "Please add entries manually to: $hostsPath"
    }
}

# Build and start
function Start-Containers {
    Write-Host ""
    $input = Read-Host "Build and start containers now? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($input)) { $input = "Y" }

    if ($input -match "^[Yy]") {
        Write-Host ""
        Write-Host "Building Docker images..." -ForegroundColor Blue
        docker compose build

        Write-Host ""
        Write-Host "Starting containers..." -ForegroundColor Blue
        docker compose up -d

        Write-Host ""
        Write-Success "Containers started successfully!"
        Write-Host ""
        Write-Host "Access RStudio Server:" -ForegroundColor Green
        for ($i = 1; $i -le $script:Instances; $i++) {
            $letter = [char](96 + $i)
            $port = $script:BasePort + $i - 1
            Write-Host "  - Instance ${letter}: http://rstudio-${letter}:$port"
            Write-Host "    Username: rstudio_$letter"
            Write-Host "    Password: rstudio_$letter"
        }
        Write-Host ""
        Write-Host "Note: Use hostname URLs (rstudio-X) for independent sessions" -ForegroundColor Yellow
    }
    else {
        Write-Host ""
        Write-Host "To build and start later, run:"
        Write-Host "  docker compose build; docker compose up -d"
    }
}

# Main
Write-Header
Get-DockerPlatform
Test-Docker
Get-Config
Initialize-Ssh
New-HomeDirs
Initialize-GitHubAuth
New-ComposeFile
Save-EnvFile
Initialize-HostsFile
Start-Containers

Write-Host ""
Write-Success "Setup complete!"
