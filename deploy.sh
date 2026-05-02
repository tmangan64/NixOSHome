#!/usr/bin/env bash
# =============================================================================
#  NixOS Home Server — Deploy Script
#  Run from a NixOS minimal live ISO:
#
#    curl -sSL https://raw.githubusercontent.com/tmangan64/NixOSHome/main/deploy.sh | bash
#
#  Progress is saved to /tmp/nixoshome_progress so you can safely restart
#  the script at any point without repeating completed steps.
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERR ]${RESET}  $*" >&2; exit 1; }
ask()     { echo -e "${BOLD}${CYAN} >>> ${RESET} $*"; }
divider() { echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"; }
header()  { echo ""; divider; echo -e "${BOLD}$*${RESET}"; divider; }

# ── Progress tracking ─────────────────────────────────────────────────────────
# Steps:
#   0 = not started
#   1 = repo cloned, config.nix written
#   2 = age key generated, .sops.yaml patched
#   3 = secrets.yaml encrypted
#   4 = loopback SSH ready
#   5 = nixos-anywhere complete (system installed)
#   6 = host age key added to .sops.yaml
#   7 = secrets re-encrypted with both keys, pushed, rebuild done

PROGRESS_FILE="/tmp/nixoshome_progress"
STATE_FILE="/tmp/nixoshome_state"   # persists collected values between runs

save_progress() { echo "STEP=$1" > "$PROGRESS_FILE"; }
load_progress() {
  if [[ -f "$PROGRESS_FILE" ]]; then
    source "$PROGRESS_FILE"
  else
    STEP=0
  fi
}
save_state() {
  cat > "$STATE_FILE" <<EOF
WORKDIR="${WORKDIR:-}"
SERVER_IP="${SERVER_IP:-}"
GATEWAY_IP="${GATEWAY_IP:-}"
GITHUB_USER="${GITHUB_USER:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
AGE_KEY_PATH="${AGE_KEY_PATH:-}"
AGE_PUBLIC_KEY="${AGE_PUBLIC_KEY:-}"
EOF
}
load_state() {
  [[ -f "$STATE_FILE" ]] && source "$STATE_FILE" || true
}

load_progress
load_state

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat <<'BANNER'
  _   _ _       ___  ____    _   _
 | \ | (_)_  __/ _ \/ ___|  | | | | ___  _ __ ___   ___
 |  \| | \ \/ / | | \___ \  | |_| |/ _ \| '_ ` _ \ / _ \
 | |\  | |>  <| |_| |___) | |  _  | (_) | | | | | |  __/
 |_| \_|_/_/\_\\___/|____/  |_| |_|\___/|_| |_| |_|\___|

          Declarative Home Server — Deploy Script
BANNER
echo -e "${RESET}"

# ── Resume notice ─────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -gt 0 ]]; then
  echo ""
  STEP_NAMES=(
    ""
    "Repo cloned & config.nix written"
    "Age key generated & .sops.yaml patched"
    "Secrets encrypted"
    "Loopback SSH ready"
    "NixOS installed — awaiting sops finalisation"
    "Host age key added to .sops.yaml"
    "Complete"
  )
  warn "Resuming from saved progress."
  info "Last completed step: ${STEP} — ${STEP_NAMES[$STEP]}"
  echo ""
  echo -e "  ${BOLD}Steps:${RESET}"
  for i in 1 2 3 4 5 6 7; do
    if [[ $i -le $STEP ]]; then
      echo -e "    ${GREEN}✓${RESET} $i. ${STEP_NAMES[$i]}"
    elif [[ $i -eq $((STEP + 1)) ]]; then
      echo -e "    ${CYAN}→${RESET} $i. ${STEP_NAMES[$i]}"
    else
      echo -e "    ${RESET}  $i. ${STEP_NAMES[$i]}"
    fi
  done
  echo ""
  read -rp "$(echo -e "${BOLD}Continue from step $((STEP + 1))? [Y/n]: ${RESET}")" RESUME
  [[ "${RESUME,,}" == "n" ]] && { save_progress 0; exec "$0"; }
else
  divider
  warn "This script will ERASE /dev/nvme0n1 and install NixOS."
  warn "Ensure your data drive (/dev/sda1) is present and formatted."
  echo ""
  read -rp "$(echo -e "${BOLD}Press ENTER to continue or Ctrl+C to abort...${RESET}")"
fi

echo ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 1 ]]; then
  header "Checking prerequisites"

  for cmd in git nix ssh-keygen age sops mkpasswd curl; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Required tool not found: $cmd — are you on the NixOS minimal ISO?"
    fi
  done

  export NIX_CONFIG="experimental-features = nix-command flakes"
  success "Prerequisites satisfied."
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Clone repo & write config.nix
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 1 ]]; then
  header "Step 1 of 7 — Clone repository & configure"

  REPO_URL="https://github.com/tmangan64/NixOSHome.git"
  WORKDIR="$(mktemp -d)"

  info "Cloning template repository..."
  git clone "$REPO_URL" "$WORKDIR/nixoshome" \
    || error "Clone failed. Check network connectivity."
  success "Cloned to $WORKDIR/nixoshome"
  echo ""

  ask "Static IP address for this server (e.g. 192.168.1.100):"
  read -r SERVER_IP
  [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || error "Invalid IP: $SERVER_IP"

  ask "Router / gateway IP address (e.g. 192.168.1.1):"
  read -r GATEWAY_IP
  [[ "$GATEWAY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || error "Invalid gateway: $GATEWAY_IP"

  ask "Your GitHub username (for auto-upgrades):"
  read -r GITHUB_USER
  [[ -n "$GITHUB_USER" ]] || error "GitHub username cannot be empty."

  ask "Your fork's repository name [default: NixOSHome]:"
  read -r GITHUB_REPO
  GITHUB_REPO="${GITHUB_REPO:-NixOSHome}"

  info "Generating SSH key pair..."
  SSH_KEY_PATH="$WORKDIR/admin_ed25519"
  ssh-keygen -t ed25519 -C "nixoshome-admin" -f "$SSH_KEY_PATH" -N "" -q
  SSH_PUBLIC_KEY="$(cat "${SSH_KEY_PATH}.pub")"
  success "SSH key pair created."

  info "Writing config.nix..."
  cat > "$WORKDIR/nixoshome/config.nix" <<EOF
# User Configuration — generated by deploy.sh $(date +%Y-%m-%d)
# To redeploy with updated settings:
#   sudo nixos-rebuild switch --flake github:${GITHUB_USER}/${GITHUB_REPO}#homeserver

{
  network = {
    serverIP = "${SERVER_IP}";
    gateway  = "${GATEWAY_IP}";
  };

  ssh = {
    publicKey = "${SSH_PUBLIC_KEY}";
  };

  github = {
    username = "${GITHUB_USER}";
    repo     = "${GITHUB_REPO}";
  };
}
EOF
  success "config.nix written."
  save_state
  save_progress 1
fi

cd "$WORKDIR/nixoshome"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Generate age key & patch .sops.yaml
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 2 ]]; then
  header "Step 2 of 7 — Age key & .sops.yaml"

  AGE_KEY_PATH="$WORKDIR/age_key.txt"
  info "Generating ephemeral age key..."
  age-keygen -o "$AGE_KEY_PATH" 2>/dev/null
  AGE_PUBLIC_KEY="$(age-keygen -y "$AGE_KEY_PATH")"
  success "Age public key: $AGE_PUBLIC_KEY"
  echo ""

  warn "This key is ephemeral. Step 6 will replace it with the server's host key."
  warn "Keep $AGE_KEY_PATH safe until Step 6 is complete."
  echo ""

  info "Patching .sops.yaml (user key slot)..."
  # Replace only the FIRST occurrence of the placeholder (user key)
  sed -i "0,/age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/s||${AGE_PUBLIC_KEY}|" .sops.yaml
  success ".sops.yaml updated — host key slot left for Step 6."

  save_state
  save_progress 2
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Collect secrets & encrypt
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 3 ]]; then
  header "Step 3 of 7 — Secrets"

  echo -e "${BOLD}Enter passwords for the server (input is hidden):${RESET}"
  echo ""

  ask "Admin account password:"
  read -rs ADMIN_PASSWORD; echo ""
  ADMIN_HASH="$(echo "$ADMIN_PASSWORD" | mkpasswd -m sha-512 -s)"

  ask "Nextcloud admin password:"
  read -rs NEXTCLOUD_PASSWORD; echo ""

  info "Encrypting secrets.yaml with sops..."
  cat > secrets/secrets.yaml <<YAML
admin:
  password_hash: ${ADMIN_HASH}
nextcloud:
  admin_password: ${NEXTCLOUD_PASSWORD}
YAML

  SOPS_AGE_KEY_FILE="$AGE_KEY_PATH" \
    sops --encrypt --age "$AGE_PUBLIC_KEY" \
    --in-place secrets/secrets.yaml \
    || error "sops encryption failed."

  unset ADMIN_PASSWORD NEXTCLOUD_PASSWORD ADMIN_HASH
  success "secrets.yaml encrypted. Plaintext cleared from memory."

  save_progress 3
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Loopback SSH
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 4 ]]; then
  header "Step 4 of 7 — Loopback SSH"

  info "Injecting public key into /root/.ssh/authorized_keys..."
  mkdir -p /root/.ssh
  cp "${SSH_KEY_PATH}.pub" /root/.ssh/authorized_keys
  chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys

  info "Starting sshd on live ISO..."
  systemctl start sshd 2>/dev/null || true
  sleep 2

  info "Pre-approving 127.0.0.1 in known_hosts..."
  mkdir -p "$HOME/.ssh"
  ssh-keyscan -p 22 127.0.0.1 2>/dev/null >> "$HOME/.ssh/known_hosts" || true

  success "Loopback SSH ready."
  save_progress 4
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Deploy via nixos-anywhere
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 5 ]]; then
  header "Step 5 of 7 — Install NixOS"

  echo ""
  warn "About to partition and format /dev/nvme0n1."
  warn "The data drive /dev/sda1 will NOT be touched."
  echo ""
  read -rp "$(echo -e "${BOLD}Type YES to confirm: ${RESET}")" CONFIRM
  [[ "$CONFIRM" == "YES" ]] || error "Installation cancelled by user."
  echo ""

  info "Running nixos-anywhere (this takes several minutes)..."
  nix run github:nix-community/nixos-anywhere -- \
    --flake "$WORKDIR/nixoshome#homeserver" \
    --target-host "root@127.0.0.1" \
    --ssh-option "StrictHostKeyChecking=no" \
    --ssh-option "IdentityFile=$SSH_KEY_PATH" \
    || error "nixos-anywhere failed. Re-run this script to retry from this step."

  success "NixOS installed."
  save_progress 5

  echo ""
  warn "The system will reboot now. After it comes back up, re-run this script"
  warn "to complete Steps 6 & 7 (sops finalisation)."
  echo ""
  info "Re-run with:"
  echo -e "  ${BOLD}curl -sSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/main/deploy.sh | bash${RESET}"
  echo ""
  read -rp "$(echo -e "${BOLD}Press ENTER to reboot...${RESET}")"
  reboot
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 — Retrieve host age key & update .sops.yaml
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 6 ]]; then
  header "Step 6 of 7 — Add server host key to .sops.yaml"

  echo ""
  info "The installed server should now be reachable at ${SERVER_IP} on port 2266."
  info "Retrieving its SSH host key and converting to age format..."
  echo ""

  HOST_AGE_KEY="$(ssh-keyscan -p 2266 "$SERVER_IP" 2>/dev/null \
    | grep ed25519 \
    | ssh-to-age)" \
    || error "Could not reach server at ${SERVER_IP}:2266. Is it up and on the network?"

  success "Host age key: $HOST_AGE_KEY"

  info "Patching second placeholder in .sops.yaml..."
  sed -i "s|age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|${HOST_AGE_KEY}|" \
    "$WORKDIR/nixoshome/.sops.yaml"
  success ".sops.yaml now contains both user and host age keys."

  save_progress 6
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 7 — Re-encrypt secrets, push, rebuild
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 7 ]]; then
  header "Step 7 of 7 — Re-encrypt, push & final rebuild"

  cd "$WORKDIR/nixoshome"

  info "Re-encrypting secrets.yaml with both keys (user + host)..."
  SOPS_AGE_KEY_FILE="$AGE_KEY_PATH" \
    sops updatekeys --yes secrets/secrets.yaml \
    || error "sops updatekeys failed. Ensure both age keys are correct in .sops.yaml"
  success "Secrets re-encrypted with both keys."
  echo ""

  info "Committing and pushing to GitHub..."
  info "You will need a GitHub Personal Access Token with repo write access."
  ask "GitHub Personal Access Token:"
  read -rs GIT_TOKEN; echo ""
  [[ -n "$GIT_TOKEN" ]] || error "Token cannot be empty."

  git remote set-url origin "https://${GITHUB_USER}:${GIT_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
  unset GIT_TOKEN

  git config user.email "deploy@nixoshome"
  git config user.name  "deploy.sh"
  git add config.nix .sops.yaml secrets/secrets.yaml
  git commit -m "chore: apply deploy.sh configuration [$(date +%Y-%m-%d)]"
  git push origin main || error "git push failed. Check your token has repo write access."
  success "Config pushed to GitHub."
  echo ""

  info "Triggering final rebuild on server..."
  ssh -p 2266 -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
    "admin@${SERVER_IP}" \
    "sudo nixos-rebuild switch --flake github:${GITHUB_USER}/${GITHUB_REPO}#homeserver" \
    || error "Rebuild failed. SSH onto the server and check: sudo journalctl -xe"

  success "Server rebuilt with full secrets support."
  save_progress 7
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Deployment complete.${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}Services:${RESET}"
echo -e "  AdGuard Home  →  https://dns.home:3000   (or https://${SERVER_IP}:3000)"
echo -e "  Nextcloud     →  https://nas.home         (point DNS / /etc/hosts to ${SERVER_IP})"
echo ""
echo -e "${BOLD}SSH access:${RESET}"
echo -e "  ssh -p 2266 -i ${SSH_KEY_PATH} admin@${SERVER_IP}"
echo ""
echo -e "${BOLD}Manual update:${RESET}"
echo -e "  sudo nixos-rebuild switch --flake github:${GITHUB_USER}/${GITHUB_REPO}#homeserver"
echo ""
echo -e "${BOLD}Rollback:${RESET}"
echo -e "  sudo nixos-rebuild switch --rollback"
echo ""
divider
info "Progress file: $PROGRESS_FILE  (delete to restart from scratch)"
info "State file:    $STATE_FILE"
info "SSH key:       ${SSH_KEY_PATH}  <- back this up!"
divider
echo ""
