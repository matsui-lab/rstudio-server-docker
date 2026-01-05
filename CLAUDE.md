# CLAUDE.md - AI Assistant Guide for rstudio-server-docker

## Project Overview

This is a Docker-based multi-instance RStudio Server environment with Claude Code CLI integration. It provides a reproducible, cross-platform (Mac Intel/M1/M2, Windows, Ubuntu, Chrome OS Flex) development environment for R and Python data science workflows.

**Repository:** `matsui-lab/rstudio-server-docker`

## Repository Structure

```
rstudio-server-docker/
├── Dockerfile              # Docker image definition (rocker/rstudio base)
├── setup.sh                # CLI setup script for Mac/Linux
├── setup.ps1               # CLI setup script for Windows PowerShell
├── setup-chromeos.sh       # CLI setup script for Chrome OS Flex
├── install.sh              # GUI installer launcher for Mac/Linux/Chrome OS
├── install.bat             # GUI installer launcher for Windows
├── .env.example            # Environment variable template
├── requirements.txt        # Python packages for reticulate
├── README.md               # Bilingual documentation (EN/JP)
├── config/
│   └── rstudio-prefs.json  # RStudio IDE preferences template
├── installer/              # Web-based GUI installer
│   ├── package.json        # Node.js dependencies (Express)
│   └── src/
│       ├── server.js       # Express API server
│       ├── main/
│       │   ├── docker.js   # Docker operations + Chrome OS detection
│       │   ├── setup.js    # Setup logic (SSH, GitHub, compose generation)
│       │   └── hosts.js    # /etc/hosts configuration
│       └── renderer/
│           ├── index.html  # Installer UI
│           ├── styles.css  # Dark theme styling
│           └── app.js      # Frontend JavaScript (fetch API)
└── [Generated at runtime]
    ├── .env                # Active environment configuration
    ├── docker-compose.yml  # Generated compose file
    ├── home_a/, home_b/... # Instance home directories
    └── ssh/                # SSH keys directory
```

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Container image: R, scientific libraries, Node.js, Claude Code CLI, GitHub CLI |
| `setup.sh` | CLI setup for Mac/Linux with interactive prompts |
| `setup.ps1` | CLI setup for Windows PowerShell |
| `setup-chromeos.sh` | CLI setup for Chrome OS Flex (Crostini) with Docker auto-install |
| `install.sh` | Launches web-based GUI installer (Mac/Linux/Chrome OS) |
| `install.bat` | Launches web-based GUI installer (Windows) |
| `installer/src/server.js` | Express server with REST API and SSE for progress |
| `installer/src/main/docker.js` | Docker checks, build, Chrome OS detection |
| `installer/src/main/setup.js` | SSH keys, GitHub auth, docker-compose.yml generation |

## Architecture

### Multi-Instance Design
- Supports 1-10 configurable RStudio instances
- Each instance has:
  - Unique hostname: `rstudio-a`, `rstudio-b`, etc.
  - Unique port: 8787, 8788, 8789, etc.
  - Unique credentials: `rstudio_a/rstudio_a`, etc.
  - Independent home directory: `home_a/`, `home_b/`, etc.

### Docker Volumes
- `renv-cache`, `renv-lib`: Shared R package cache across instances
- SSH keys: Read-only bind mount
- Claude config: Mounted from host's `~/.claude`

### Platform Support
| Platform | CLI Script | GUI Installer | Access URL |
|----------|------------|---------------|------------|
| Mac (Intel/M1/M2) | `setup.sh` | `install.sh` | `http://rstudio-a:8787` |
| Windows | `setup.ps1` | `install.bat` | `http://rstudio-a:8787` |
| Ubuntu/Debian | `setup.sh` | `install.sh` | `http://rstudio-a:8787` |
| Chrome OS Flex | `setup-chromeos.sh` | `install.sh` | `http://penguin.linux.test:8787` |

### GUI Installer Architecture
```
Browser (http://localhost:3000)
    ↓ fetch API
Express Server (server.js)
    ├── /api/platform        → Platform info
    ├── /api/docker/*        → Docker status
    ├── /api/chromeos/*      → Chrome OS detection
    ├── /api/ssh/*           → SSH key operations
    ├── /api/hosts/*         → /etc/hosts management
    ├── /api/setup/stream    → SSE progress updates
    └── /api/setup/run       → Execute full setup
```

## Development Workflows

### Initial Setup (CLI)
```bash
# Mac/Linux
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
./setup.sh

# Windows PowerShell
.\setup.ps1

# Chrome OS Flex (in Linux terminal)
./setup-chromeos.sh
```

### Initial Setup (GUI)
```bash
# Mac/Linux/Chrome OS Flex
./install.sh
# Opens http://localhost:3000 in browser

# Windows
.\install.bat
```

### Common Docker Commands
```bash
docker compose up -d              # Start all containers
docker compose down               # Stop all containers
docker compose logs -f            # View live logs
docker compose build --no-cache   # Rebuild images
docker compose ps                 # Check running containers
```

### Accessing Instances
| Platform | URL Format |
|----------|------------|
| Mac/Windows/Ubuntu | `http://rstudio-a:8787` |
| Chrome OS Flex (Chrome browser) | `http://penguin.linux.test:8787` |
| Chrome OS Flex (Linux terminal) | `http://localhost:8787` |

- Credentials: username matches hostname suffix (e.g., `rstudio_a`)
- Session isolation requires using hostnames (configured in /etc/hosts)

## Code Conventions

### Shell Scripts (setup.sh, setup-chromeos.sh)
- Functions use `snake_case` naming
- Interactive prompts use `read -p` with sensible defaults
- Error handling with `set -e`
- Platform detection before operations
- Idempotent operations (safe to re-run)

### PowerShell Scripts (setup.ps1)
- Functions use `PascalCase` naming
- Uses `Write-Host` for output, `Read-Host` for input
- `SecureString` for sensitive inputs (passwords, PATs)

### Node.js/Express (installer/)
- ES modules style imports
- Async/await for all async operations
- Server-Sent Events (SSE) for progress streaming
- REST API endpoints under `/api/`

### Dockerfile
- Multi-layer optimization (grouped RUN commands)
- Non-interactive apt-get with auto-cleanup
- Environment variables set at build time
- R packages installed via install2.r

## Configuration Options

| Option | Default | Range | Description |
|--------|---------|-------|-------------|
| `RSTUDIO_INSTANCES` | 5 | 1-10 | Number of RStudio containers |
| `RSTUDIO_BASE_PORT` | 8787 | valid port | Starting port number |
| `SHARE_CLAUDE_CONFIG` | true | bool | Mount host's Claude config |
| `INCLUDE_RUNNER` | true | bool | Include batch processing container |

## Installed Software Stack

### In Docker Image
- **R**: Latest from rocker/rstudio with renv
- **Python**: venv at `/opt/venv` (for reticulate)
- **Node.js**: 20.x with Claude Code CLI
- **GitHub CLI**: gh for authentication
- **Build tools**: make, cmake, gfortran
- **Scientific libs**: OpenBLAS, LAPACK, FFTW, GSL, HDF5
- **Geospatial**: GDAL, GEOS, PROJ, NetCDF
- **R packages**: renv, reticulate, devtools, testthat, lintr, styler

### GUI Installer Dependencies
- **Node.js**: v18+ required
- **Express**: Web server
- **open**: Browser auto-launch

## Important Notes for AI Assistants

### When Modifying This Project

1. **Dockerfile changes** require `docker compose build --no-cache` to take effect
2. **setup.sh/setup.ps1/setup-chromeos.sh** must remain functionally equivalent
3. **Generated files** (.env, docker-compose.yml, home_*/) are gitignored
4. **README.md** is bilingual - update both English and Japanese sections
5. **Hostnames** (not localhost) are required for proper session isolation
6. **installer/** uses Express (not Electron) - web-based, no native dependencies

### Common Tasks

**Adding Python packages:**
1. Edit `requirements.txt`
2. Rebuild: `docker compose build --no-cache`

**Adding R packages:**
1. Install via renv inside container (cached automatically)
2. Or add to Dockerfile's install2.r command

**Adding system libraries:**
1. Modify Dockerfile apt-get install list
2. Rebuild image

**Modifying GUI installer:**
1. Backend: Edit `installer/src/server.js` or `installer/src/main/*.js`
2. Frontend: Edit `installer/src/renderer/app.js`
3. Test: `cd installer && npm start`

**Adding new platform support:**
1. Create platform-specific setup script if needed
2. Add detection in `installer/src/main/docker.js`
3. Add API endpoint in `installer/src/server.js`
4. Update README.md (both EN/JP sections)

### Files to Never Commit
- `.env` (contains user configuration)
- `docker-compose.yml` (generated from setup)
- `home_*/` directories (user data)
- `ssh/` directory (private keys)
- `installer/node_modules/` (npm dependencies)
- Any files containing credentials or tokens

### Testing Changes

**CLI Scripts:**
1. Run setup script with test configuration
2. Verify containers start: `docker compose ps`
3. Access RStudio at configured hostname:port

**GUI Installer:**
1. `cd installer && npm install && npm start`
2. Open http://localhost:3000
3. Walk through setup wizard
4. Verify all API endpoints respond correctly

**In Container:**
1. Test Claude Code: `claude --version`
2. Test GitHub: `gh auth status`

## Build & Run Commands

```bash
# Full rebuild
docker compose down
docker compose build --no-cache
docker compose up -d

# View specific instance logs
docker compose logs -f rstudio-a

# Execute command in container
docker compose exec rstudio-a bash

# Batch processing (runner container)
docker compose run --rm runner "R CMD BATCH script.R"

# Run GUI installer in dev mode
cd installer && npm start
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Port already in use | Change `RSTUDIO_BASE_PORT` in setup |
| Session bleeding between instances | Use hostnames, not localhost |
| R packages not persisting | Check renv-cache volume exists |
| Claude CLI not found | Rebuild image, verify Node.js installation |
| GitHub auth failing | Re-run setup with new PAT |
| GUI installer won't start | Check Node.js v18+ installed |
| Chrome OS: Docker permission denied | Log out and log back in after Docker install |
| Chrome OS: Can't access from browser | Use `http://penguin.linux.test:PORT` |
