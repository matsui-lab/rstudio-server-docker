FROM rocker/rstudio:latest

ARG DEBIAN_FRONTEND=noninteractive

# --- OS packages: build tools + git/ssh + python ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client make cmake \
    python3 python3-venv python3-pip \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libgit2-dev libicu-dev \
    ca-certificates curl gnupg \
    && rm -rf /var/lib/apt/lists/*

# --- Scientific computing libraries (Fortran, BLAS, LAPACK, OpenMP) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Fortran compiler
    gfortran \
    # BLAS/LAPACK (OpenBLAS - optimized)
    libopenblas-dev liblapack-dev \
    # OpenMP
    libomp-dev libgomp1 \
    # Additional scientific libraries
    libfftw3-dev \
    libgsl-dev \
    libhdf5-dev \
    libnetcdf-dev \
    # Geospatial libraries (for sf, terra, etc.)
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libsqlite3-dev \
    # Image processing
    libmagick++-dev \
    libpng-dev libjpeg-dev libtiff-dev \
    # Other common dependencies
    libfontconfig1-dev libfreetype6-dev \
    libharfbuzz-dev libfribidi-dev \
    && rm -rf /var/lib/apt/lists/*

# --- GitHub known_hosts (avoid interactive prompts for SSH) ---
RUN mkdir -p /etc/ssh && ssh-keyscan github.com >> /etc/ssh/ssh_known_hosts

# --- Python venv (fixed Python for reticulate) ---
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip wheel setuptools

# Install Python requirements if provided
COPY requirements.txt /tmp/requirements.txt
RUN if [ -s /tmp/requirements.txt ]; then /opt/venv/bin/pip install -r /tmp/requirements.txt; fi

# --- R dev/tooling packages ---
RUN install2.r --error \
    renv reticulate devtools testthat rcmdcheck covr \
    lintr styler optparse yaml jsonlite \
 && rm -rf /tmp/downloaded_packages

# --- Node.js (for Claude Code CLI) ---
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g @anthropic-ai/claude-code \
 && npm cache clean --force \
 && rm -rf /var/lib/apt/lists/*

# --- GitHub CLI (gh) ---
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
 && apt-get update \
 && apt-get install -y gh \
 && rm -rf /var/lib/apt/lists/*

# --- Environment variables ---
ENV RETICULATE_PYTHON=/opt/venv/bin/python
ENV RENV_PATHS_CACHE=/opt/renv/cache
ENV RENV_PATHS_LIBRARY=/opt/renv/library

# --- Setup renv directories ---
RUN mkdir -p /opt/renv/cache /opt/renv/library \
 && chown -R rstudio:rstudio /opt/renv

WORKDIR /home/rstudio
