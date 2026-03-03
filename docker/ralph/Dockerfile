FROM python:3.13-bookworm

ARG TZ=${TZ:-UTC}
ENV TZ=${TZ}

# System dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       jq curl ca-certificates gh git sudo \
       iptables ipset iproute2 dnsutils aggregate \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -m -s /bin/bash ralph

# Claude Code CLI (install as ralph so it lands in /home/ralph/.local/)
USER ralph

RUN curl -fsSL https://claude.ai/install.sh | bash

COPY --from=ghcr.io/astral-sh/uv:0.10.7 /uv /uvx /bin/

USER root

# Firewall init script
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh

# Allow ralph to run firewall without password
RUN echo "ralph ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/ralph-firewall \
    && chmod 0440 /etc/sudoers.d/ralph-firewall

ENV DEVCONTAINER=true
ENV DISABLE_AUTOUPDATER=1
ENV PATH="/home/ralph/.local/bin:${PATH}"

WORKDIR /workspace
USER ralph
