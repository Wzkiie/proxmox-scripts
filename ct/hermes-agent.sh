#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 community-scripts ORG
# Author: Jacob Steiniger (stnger)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/NousResearch/hermes-agent

APP="Hermes Agent"
var_tags="${var_tags:-ai;agent}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/hermes-agent ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Stopping ${APP} Service"
  systemctl stop hermes-gateway 2>/dev/null || true
  msg_ok "Stopped ${APP} Service"

  msg_info "Updating ${APP}"
  cd /opt/hermes-agent
  git pull origin main
  /opt/hermes-agent/venv/bin/pip install -e '.[all]' --quiet
  msg_ok "Updated ${APP}"

  msg_info "Starting ${APP} Service"
  systemctl start hermes-gateway 2>/dev/null || true
  msg_ok "Started ${APP} Service"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access Hermes Agent CLI:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Enter container:${CL} pct enter \$CTID"
echo -e "${TAB}${GATEWAY}${BGN}Start chat:${CL} hermes"
echo -e "${TAB}${GATEWAY}${BGN}Configure:${CL} nano /root/.hermes/.env"
