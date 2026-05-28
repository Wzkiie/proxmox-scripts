#!/usr/bin/env bash

# Copyright (c) 2025 community-scripts ORG
# Author: Jacob Steiniger (stnger)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/NousResearch/hermes-agent

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# ─────────────────────────────────────────────
# Dependencies
# ─────────────────────────────────────────────

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  wget \
  git \
  build-essential \
  python3 \
  python3-dev \
  python3-venv \
  python3-pip \
  libffi-dev \
  libssl-dev \
  ripgrep \
  ffmpeg \
  nodejs \
  npm \
  ca-certificates \
  gnupg \
  lsb-release
msg_ok "Installed Dependencies"

# ─────────────────────────────────────────────
# uv (fast Python package manager)
# ─────────────────────────────────────────────

msg_info "Installing uv"
$STD curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="/root/.local/bin:$PATH"
echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc
msg_ok "Installed uv"

# ─────────────────────────────────────────────
# Hermes Agent
# ─────────────────────────────────────────────

msg_info "Cloning Hermes Agent"
$STD git clone --branch main https://github.com/NousResearch/hermes-agent.git /opt/hermes-agent
msg_ok "Cloned Hermes Agent"

msg_info "Creating Python venv"
cd /opt/hermes-agent
$STD uv venv venv --python 3.11
msg_ok "Created Python venv"

msg_info "Installing Hermes Agent (this may take a few minutes)"
$STD /opt/hermes-agent/venv/bin/uv pip install -e '.[all]'
msg_ok "Installed Hermes Agent"

# ─────────────────────────────────────────────
# Playwright / Chromium (optional, best-effort)
# ─────────────────────────────────────────────

msg_info "Installing Node.js dependencies"
cd /opt/hermes-agent
$STD npm install --silent
msg_ok "Installed Node.js dependencies"

msg_info "Installing Playwright Chromium"
$STD npx playwright install --with-deps chromium
msg_ok "Installed Playwright Chromium"

# ─────────────────────────────────────────────
# Config & data directories
# ─────────────────────────────────────────────

msg_info "Setting up configuration"
mkdir -p /root/.hermes/{cron,sessions,logs,pairing,hooks,image_cache,audio_cache,memories,skills}

# .env aus Template
if [[ -f /opt/hermes-agent/.env.example ]]; then
  cp /opt/hermes-agent/.env.example /root/.hermes/.env
else
  touch /root/.hermes/.env
fi
chmod 600 /root/.hermes/.env

# config.yaml aus Template
if [[ -f /opt/hermes-agent/cli-config.yaml.example ]]; then
  cp /opt/hermes-agent/cli-config.yaml.example /root/.hermes/config.yaml
fi

# SOUL.md (Persona)
cat > /root/.hermes/SOUL.md << 'SOUL_EOF'
# Hermes Agent Persona

<!--
Edit this file to customize how Hermes communicates with you.
This file is loaded fresh each message — no restart needed.
Delete the contents to use the default personality.
-->
SOUL_EOF

msg_ok "Configuration set up at /root/.hermes/"

# ─────────────────────────────────────────────
# hermes command in PATH
# ─────────────────────────────────────────────

msg_info "Linking hermes command"
mkdir -p /root/.local/bin
cat > /root/.local/bin/hermes << 'CMD_EOF'
#!/usr/bin/env bash
unset PYTHONPATH
unset PYTHONHOME
exec /opt/hermes-agent/venv/bin/hermes "$@"
CMD_EOF
chmod +x /root/.local/bin/hermes

# Auch in /usr/local/bin für alle Shells ohne PATH-Anpassung
ln -sf /opt/hermes-agent/venv/bin/hermes /usr/local/bin/hermes

echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc
echo 'export HERMES_HOME="/root/.hermes"' >> /root/.bashrc
msg_ok "hermes command linked to /usr/local/bin/hermes"

# ─────────────────────────────────────────────
# systemd service (Gateway für Messaging-Bots)
# ─────────────────────────────────────────────

msg_info "Creating systemd service (hermes-gateway)"
cat > /etc/systemd/system/hermes-gateway.service << 'SERVICE_EOF'
[Unit]
Description=Hermes Agent Gateway (Telegram/Discord/Slack)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/hermes-agent
Environment="PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin"
Environment="HERMES_HOME=/root/.hermes"
EnvironmentFile=-/root/.hermes/.env
ExecStart=/opt/hermes-agent/venv/bin/hermes gateway
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl enable hermes-gateway --quiet
# Noch nicht starten — erst nach .env konfigurieren
msg_ok "systemd service created (enable after configuring .env)"

# ─────────────────────────────────────────────
# MOTD
# ─────────────────────────────────────────────

msg_info "Setting MOTD"
cat > /etc/motd << 'MOTD_EOF'

  ██╗  ██╗███████╗██████╗ ███╗   ███╗███████╗███████╗
  ██║  ██║██╔════╝██╔══██╗████╗ ████║██╔════╝██╔════╝
  ███████║█████╗  ██████╔╝██╔████╔██║█████╗  ███████╗
  ██╔══██║██╔══╝  ██╔══██╗██║╚██╔╝██║██╔══╝  ╚════██║
  ██║  ██║███████╗██║  ██║██║ ╚═╝ ██║███████╗███████║
  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝
         Hermes Agent — by Nous Research

  Quick start:
    hermes                     Start chatting
    hermes setup               Configure API keys
    nano /root/.hermes/.env    Edit config directly
    systemctl start hermes-gateway   Start bot gateway

MOTD_EOF
msg_ok "MOTD set"

# ─────────────────────────────────────────────
# Abschluss
# ─────────────────────────────────────────────

motd_ssh
customize
