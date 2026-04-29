FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Base tools + fish shell + asciinema
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && apt-add-repository ppa:fish-shell/release-4 \
    && apt-get update && apt-get install -y \
    fish \
    asciinema \
    bat \
    curl \
    ca-certificates \
    build-essential \
    libssl-dev \
    pkg-config \
    jq \
    bc \
    git \
    file \
    fonts-jetbrains-mono \
    && rm -rf /var/lib/apt/lists/*

# Symlink batcat -> bat (Ubuntu names it batcat to avoid conflict)
RUN ln -s /usr/bin/batcat /usr/local/bin/bat

# Install Docker CLI (client only — uses host daemon via socket mount)
RUN curl -fsSL https://get.docker.com | sh

# Install yq (arch-aware)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -sL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" \
    -o /usr/bin/yq && chmod +x /usr/bin/yq

# Install Rust + agg (heaviest layer — cached)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install --git https://github.com/asciinema/agg

# Install Starship prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Copy configuration
COPY config/starship.toml /etc/starship.toml
COPY config/config.fish /etc/fish/conf.d/termforge.fish

# Copy scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh /app/scripts/*.fish

# Create mount points
RUN mkdir -p /input /output/casts /output/gifs

ENV STARSHIP_CONFIG=/etc/starship.toml
ENV TERM=xterm-256color
ENV BAT_PAGER="/app/scripts/auto-scroll.sh"
ENV BAT_STYLE="numbers,grid,header"

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
