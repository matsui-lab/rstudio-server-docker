# CLAUDE.md - AI Assistant Guide for rstudio-server-docker

## Project Overview

This is a Docker-based multi-instance RStudio Server environment with Claude Code CLI integration. It provides a reproducible, cross-platform (Mac Intel/M1/M2, Windows, Ubuntu) development environment for R and Python data science workflows.

**Repository:** `matsui-lab/rstudio-server-docker`

## Repository Structure

```
rstudio-server-docker/
├── Dockerfile              # Docker image definition (rocker/rstudio base)
├── setup.sh                # Interactive setup script for Mac/Linux
├── setup.ps1               # Interactive setup script for Windows PowerShell
├── .env.example            # Environment variable template
├── requirements.txt        # Python packages for reticulate (template)
├── README.md               # Bilingual documentation (EN/JP)
├── config/
│   └── rstudio-prefs.json  # RStudio IDE preferences template
└── [Generated at runtime]
    ├── .env                # Active environment configuration
    ├── docker-compose.yml  # Generated compose file
    ├── home_a/, home_b/... # Instance home directories
    └── ssh/                # SSH keys directory
```

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Defines the container image: R environment, scientific libraries, Node.js, Claude Code CLI, GitHub CLI |
| `setup.sh` | Bash setup script with interactive prompts for configuration |
| `setup.ps1` | PowerShell equivalent for Windows users |
| `.env.example` | Template for environment variables (instances, ports, etc.) |
| `config/rstudio-prefs.json` | RStudio IDE preferences (theme, panes, shell) |

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

### Platform Detection
- Automatic architecture detection (x86_64 vs arm64/M1/M2)
- Platform-specific scripts handle OS differences

## Development Workflows

### Initial Setup
```bash
# Clone and run setup
git clone git@github.com:matsui-lab/rstudio-server-docker.git
cd rstudio-server-docker
./setup.sh          # Mac/Linux
# or
.\setup.ps1         # Windows PowerShell
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
- URL pattern: `http://rstudio-a:8787` (use hostnames, not localhost)
- Credentials: username matches hostname suffix (e.g., `rstudio_a`)
- Session isolation requires using hostnames (configured in /etc/hosts)

## Code Conventions

### Shell Scripts (setup.sh)
- Functions use `snake_case` naming
- Interactive prompts use `read -p` with sensible defaults
- Error handling with `set -e` consideration
- Platform detection before operations
- Idempotent operations (safe to re-run)

### PowerShell Scripts (setup.ps1)
- Functions use `PascalCase` naming (PowerShell convention)
- Uses `Write-Host` for output, `Read-Host` for input
- `SecureString` for sensitive inputs (passwords, PATs)
- Same logical flow as Bash version

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

## Important Notes for AI Assistants

### When Modifying This Project

1. **Dockerfile changes** require `docker compose build --no-cache` to take effect
2. **setup.sh/setup.ps1** must remain functionally equivalent
3. **Generated files** (.env, docker-compose.yml, home_*/) are gitignored
4. **README.md** is bilingual - update both English and Japanese sections
5. **Hostnames** (not localhost) are required for proper session isolation

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

**Changing RStudio preferences:**
1. Edit `config/rstudio-prefs.json` before setup
2. Or edit in instance's `home_X/.config/rstudio/rstudio-prefs.json`

### Files to Never Commit
- `.env` (contains user configuration)
- `docker-compose.yml` (generated from setup)
- `home_*/` directories (user data)
- `ssh/` directory (private keys)
- Any files containing credentials or tokens

### Testing Changes
1. Run setup script with test configuration
2. Verify containers start: `docker compose ps`
3. Access RStudio at configured hostname:port
4. Test Claude Code: `claude --version` in RStudio terminal
5. Test GitHub: `gh auth status` in RStudio terminal

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
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Port already in use | Change `RSTUDIO_BASE_PORT` in setup |
| Session bleeding between instances | Use hostnames, not localhost |
| R packages not persisting | Check renv-cache volume exists |
| Claude CLI not found | Rebuild image, verify Node.js installation |
| GitHub auth failing | Re-run setup with new PAT |
