# DevYeeter: Multi-language Development Environment
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies and common tools
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    cmake \
    pkg-config \
    # Version control
    git \
    # Network tools
    curl \
    wget \
    netcat \
    socat \
    net-tools \
    # Editors
    vim \
    emacs-nox \
    nano \
    # Utilities
    ca-certificates \
    software-properties-common \
    gnupg \
    lsb-release \
    zip \
    unzip \
    jq \
    tree \
    htop \
    sudo \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install C/C++ tools (gcc, g++, gdb)
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    gdb \
    clang \
    lldb \
    valgrind \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Create symlinks for python/pip
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

# Install Node.js LTS (v22)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (architecture-aware)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    else \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    fi && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client tools
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Go (architecture-aware)
ENV GO_VERSION=1.21.5
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then \
        GO_ARCH="arm64"; \
    else \
        GO_ARCH="amd64"; \
    fi && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | tar -C /usr/local -xzf - && \
    ln -s /usr/local/go/bin/go /usr/local/bin/go && \
    ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

ENV PATH="/usr/local/go/bin:${PATH}"

# Create dev user with sudo access
RUN useradd -m -s /bin/bash -u 1000 dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to dev user
USER dev
WORKDIR /home/dev

# Set up environment for dev user
ENV HOME=/home/dev
ENV USER=dev

# Install pnpm (main package manager) as dev user
RUN curl -fsSL https://get.pnpm.io/install.sh | bash -
ENV PNPM_HOME="/home/dev/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:/home/dev/.local/share/pnpm/global/5/node_modules/.bin:${PATH}"

# Install TypeScript globally via pnpm
RUN /home/dev/.local/share/pnpm/pnpm add -g typescript ts-node

# Set up Go environment for dev user
ENV GOPATH="/home/dev/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Install Rust as dev user
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/home/dev/.cargo/bin:${PATH}"

# Create workspace directory with proper permissions
RUN sudo mkdir -p /workspace && sudo chown dev:dev /workspace

# Switch back to root to set up entrypoint
USER root

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set working directory
WORKDIR /workspace

# Reset DEBIAN_FRONTEND
ENV DEBIAN_FRONTEND=dialog

# Set entrypoint to handle dynamic UID/GID mapping
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command
CMD ["/bin/bash"]
