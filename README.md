# RStudio Server Docker

Docker-based RStudio Server with Claude Code CLI integration.

[日本語版はこちら](#日本語)

## Features

- Multiple RStudio Server instances (configurable 1-10)
- Cross-platform support (Mac Intel/M1/M2, Windows, Ubuntu)
- Claude Code CLI pre-installed
- GitHub CLI (gh) pre-installed with PAT authentication
- Scientific computing libraries (gfortran, OpenBLAS, LAPACK, OpenMP, FFTW, GSL, HDF5)
- Geospatial libraries (GDAL, GEOS, PROJ, NetCDF)
- Python (venv) + R (renv) for reproducible environments
- SSH key sharing for GitHub integration
- Shared renv cache across instances

## Requirements

- Git
- Docker Desktop (Mac/Windows) or Docker Engine (Linux)
- Docker Compose v2
- Node.js v18+ (for GUI Installer only)

## Prerequisites Installation

### Mac

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Git
brew install git

# Install Docker Desktop
# Download from: https://docs.docker.com/desktop/install/mac-install/
# Or use Homebrew:
brew install --cask docker

# Install Node.js (for GUI Installer)
brew install node
```

### Windows

```powershell
# Install Git
# Download from: https://git-scm.com/download/win
# Or use winget:
winget install Git.Git

# Install Docker Desktop
# Download from: https://docs.docker.com/desktop/install/windows-install/
# Or use winget:
winget install Docker.DockerDesktop

# Install Node.js (for GUI Installer)
# Download from: https://nodejs.org/
# Or use winget:
winget install OpenJS.NodeJS.LTS

# Restart PowerShell after installation
```

### Ubuntu / Debian

```bash
# Install Git
sudo apt update
sudo apt install -y git

# Install Docker
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group (logout required)
sudo usermod -aG docker $USER

# Install Node.js (for GUI Installer)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### Chrome OS Flex

Chrome OS Flex requires the Linux development environment (Crostini).

#### Enable Linux Development Environment
1. Open **Settings**
2. Go to **Advanced** > **Developers**
3. Turn on **Linux development environment**
4. Follow the setup prompts (this may take several minutes)

#### Install Prerequisites (in Linux Terminal)
```bash
# Install Git
sudo apt update && sudo apt install -y git

# Install Docker
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group (logout and login required)
sudo usermod -aG docker $USER

# Install Node.js (for GUI Installer)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

**Important**: After installing Docker, log out and log back in for the group membership to take effect.

## Quick Start

### Mac / Linux

```bash
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
./setup.sh
```

### Windows (PowerShell)

```powershell
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
.\setup.ps1
```

### Chrome OS Flex (in Linux Terminal)

```bash
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
./setup-chromeos.sh
```

### GUI Installer (All Platforms)

For a graphical interface, use the web-based installer:

```bash
# Mac / Linux / Chrome OS Flex
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
./install.sh
```

```powershell
# Windows
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
.\install.bat
```

The installer will automatically open http://localhost:3000 in your browser.

## Configuration Options

The setup script will prompt for:

| Option | Description | Default |
|--------|-------------|---------|
| Instances | Number of RStudio instances | 5 |
| Base Port | Starting port number | 8787 |
| SSH Keys | Copy existing / Generate new / Skip | Copy existing |
| Claude Config | Share host's ~/.claude | Yes |
| Runner | Include batch processing container | Yes |
| GitHub PAT | Personal Access Token for git/gh commands | Optional |
| Hosts File | Add entries to /etc/hosts for session isolation | Yes |

### GitHub PAT Setup

To use `git` and `gh` commands inside containers, you need a Personal Access Token:

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `read:org`, `workflow`
4. Copy the token and paste it during setup

The setup script will configure:
- `.git-credentials` for HTTPS authentication
- `.gitconfig` with credential helper
- `gh` CLI authentication

## Access

After setup, access RStudio Server using hostnames (for independent sessions):

### Mac / Windows / Ubuntu

- Instance a: http://rstudio-a:8787 (user: `rstudio_a`, pass: `rstudio_a`)
- Instance b: http://rstudio-b:8788 (user: `rstudio_b`, pass: `rstudio_b`)
- ...

### Chrome OS Flex

From Chrome browser:
- Instance a: http://penguin.linux.test:8787
- Instance b: http://penguin.linux.test:8788
- ...

From Linux terminal:
- Instance a: http://localhost:8787 or http://rstudio-a:8787
- ...

**Important**: Use hostname URLs (`rstudio-a`, `rstudio-b`, etc.) instead of `localhost` to ensure each instance maintains independent sessions.

### Manual Hosts File Setup

If you skipped the automatic setup, add these entries to your hosts file:

**Mac/Linux** (`/etc/hosts`):
```
127.0.0.1 rstudio-a
127.0.0.1 rstudio-b
127.0.0.1 rstudio-c
...
```

**Windows** (`C:\Windows\System32\drivers\etc\hosts`):
```
127.0.0.1 rstudio-a
127.0.0.1 rstudio-b
127.0.0.1 rstudio-c
...
```

## Directory Structure

```
rstudio-server-docker/
├── setup.sh / setup.ps1   # Setup scripts
├── docker-compose.yml     # Generated by setup
├── Dockerfile
├── .env                   # Generated configuration
├── home_a/, home_b/...    # User home directories
├── ssh/                   # Shared SSH keys
├── config/
│   └── rstudio-prefs.json
└── requirements.txt       # Python packages
```

## Commands

```bash
# Start all containers
docker compose up -d

# Stop all containers
docker compose down

# View logs
docker compose logs -f

# Rebuild after Dockerfile changes
docker compose build --no-cache

# Run R script in batch mode
docker compose run --rm runner "cd /home/rstudio_a/project && Rscript script.R"
```

## Customization

### Python Packages

Edit `requirements.txt` and rebuild:

```bash
docker compose build --no-cache
```

### R Packages

Packages installed via renv are cached in Docker volumes and shared across instances.

### RStudio Preferences

Edit `config/rstudio-prefs.json` before setup, or modify in each `home_X/.config/rstudio/` directory.

---

# 日本語

Docker ベースの RStudio Server（Claude Code CLI 統合済み）

## 機能

- 複数の RStudio Server インスタンス（1-10個設定可能）
- クロスプラットフォーム対応（Mac Intel/M1/M2、Windows、Ubuntu）
- Claude Code CLI プリインストール済み
- GitHub CLI (gh) プリインストール済み（PAT認証対応）
- 科学計算ライブラリ（gfortran, OpenBLAS, LAPACK, OpenMP, FFTW, GSL, HDF5）
- 地理空間ライブラリ（GDAL, GEOS, PROJ, NetCDF）
- Python (venv) + R (renv) による再現可能な環境
- GitHub 連携用 SSH 鍵共有
- インスタンス間での renv キャッシュ共有

## 必要条件

- Git
- Docker Desktop (Mac/Windows) または Docker Engine (Linux)
- Docker Compose v2
- Node.js v18+（GUI インストーラー使用時のみ）

## 前提ソフトウェアのインストール

### Mac

```bash
# Homebrew をインストール（未インストールの場合）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Git をインストール
brew install git

# Docker Desktop をインストール
# ダウンロード: https://docs.docker.com/desktop/install/mac-install/
# または Homebrew で:
brew install --cask docker

# Node.js をインストール（GUI インストーラー用）
brew install node
```

### Windows

```powershell
# Git をインストール
# ダウンロード: https://git-scm.com/download/win
# または winget で:
winget install Git.Git

# Docker Desktop をインストール
# ダウンロード: https://docs.docker.com/desktop/install/windows-install/
# または winget で:
winget install Docker.DockerDesktop

# Node.js をインストール（GUI インストーラー用）
# ダウンロード: https://nodejs.org/
# または winget で:
winget install OpenJS.NodeJS.LTS

# インストール後、PowerShell を再起動
```

### Ubuntu / Debian

```bash
# Git をインストール
sudo apt update
sudo apt install -y git

# Docker をインストール
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ユーザーを docker グループに追加（ログアウトが必要）
sudo usermod -aG docker $USER

# Node.js をインストール（GUI インストーラー用）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

### Chrome OS Flex

Chrome OS Flex では Linux 開発環境（Crostini）が必要です。

#### Linux 開発環境の有効化
1. **設定**を開く
2. **詳細設定** > **デベロッパー**に移動
3. **Linux 開発環境**をオンにする
4. 指示に従ってセットアップ（数分かかる場合があります）

#### 前提ソフトウェアのインストール（Linux ターミナル内）
```bash
# Git をインストール
sudo apt update && sudo apt install -y git

# Docker をインストール
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ユーザーを docker グループに追加（ログアウト/ログインが必要）
sudo usermod -aG docker $USER

# Node.js をインストール（GUI インストーラー用）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

**重要**: Docker インストール後、グループ設定を反映するためにログアウト/ログインが必要です。

## クイックスタート

### Mac / Linux

```bash
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
./setup.sh
```

### Windows (PowerShell)

```powershell
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
.\setup.ps1
```

### Chrome OS Flex（Linux ターミナル内）

```bash
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
./setup-chromeos.sh
```

### GUI インストーラー（全プラットフォーム対応）

グラフィカルインターフェースを使用する場合は、Web ベースのインストーラーを使用:

```bash
# Mac / Linux / Chrome OS Flex
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
./install.sh
```

```powershell
# Windows
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
.\install.bat
```

インストーラーは自動的にブラウザで http://localhost:3000 を開きます。

## 設定オプション

セットアップスクリプトで以下を設定:

| オプション | 説明 | デフォルト |
|-----------|------|----------|
| インスタンス数 | RStudio インスタンスの数 | 5 |
| ベースポート | 開始ポート番号 | 8787 |
| SSH 鍵 | 既存をコピー / 新規生成 / スキップ | 既存をコピー |
| Claude 設定 | ホストの ~/.claude を共有 | はい |
| Runner | バッチ処理用コンテナを含める | はい |
| GitHub PAT | git/gh コマンド用の Personal Access Token | 任意 |
| Hosts ファイル | セッション分離用に /etc/hosts にエントリ追加 | はい |

### GitHub PAT の設定

コンテナ内で `git` や `gh` コマンドを使用するには、Personal Access Token が必要です：

1. https://github.com/settings/tokens にアクセス
2. 「Generate new token (classic)」をクリック
3. スコープを選択: `repo`, `read:org`, `workflow`
4. トークンをコピーし、セットアップ時に入力

セットアップスクリプトは以下を設定します：
- `.git-credentials`（HTTPS認証用）
- `.gitconfig`（credential helper設定）
- `gh` CLI の認証

## アクセス

セットアップ後、ホスト名を使ってアクセス（セッション独立のため）:

### Mac / Windows / Ubuntu

- インスタンス a: http://rstudio-a:8787 (ユーザー: `rstudio_a`, パスワード: `rstudio_a`)
- インスタンス b: http://rstudio-b:8788 (ユーザー: `rstudio_b`, パスワード: `rstudio_b`)
- ...

### Chrome OS Flex

Chrome ブラウザから:
- インスタンス a: http://penguin.linux.test:8787
- インスタンス b: http://penguin.linux.test:8788
- ...

Linux ターミナルから:
- インスタンス a: http://localhost:8787 または http://rstudio-a:8787
- ...

**重要**: 各インスタンスで独立したセッションを維持するため、`localhost` ではなくホスト名 URL（`rstudio-a`, `rstudio-b` など）を使用してください。

### Hosts ファイルの手動設定

自動設定をスキップした場合は、以下のエントリを追加してください：

**Mac/Linux** (`/etc/hosts`):
```
127.0.0.1 rstudio-a
127.0.0.1 rstudio-b
127.0.0.1 rstudio-c
...
```

**Windows** (`C:\Windows\System32\drivers\etc\hosts`):
```
127.0.0.1 rstudio-a
127.0.0.1 rstudio-b
127.0.0.1 rstudio-c
...
```

## コマンド

```bash
# 全コンテナ起動
docker compose up -d

# 全コンテナ停止
docker compose down

# ログ表示
docker compose logs -f

# Dockerfile 変更後に再ビルド
docker compose build --no-cache

# バッチモードで R スクリプト実行
docker compose run --rm runner "cd /home/rstudio_a/project && Rscript script.R"
```

## カスタマイズ

### Python パッケージ

`requirements.txt` を編集して再ビルド:

```bash
docker compose build --no-cache
```

### R パッケージ

renv でインストールしたパッケージは Docker ボリュームにキャッシュされ、インスタンス間で共有されます。

### RStudio 設定

セットアップ前に `config/rstudio-prefs.json` を編集するか、各 `home_X/.config/rstudio/` ディレクトリで変更してください。
