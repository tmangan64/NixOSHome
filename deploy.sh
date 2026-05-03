#!/usr/bin/env bash
# =============================================================================
#  NixOS Home Server — Deploy Script
#  Run from a NixOS minimal live ISO:
#
#    curl -sSL https://raw.githubusercontent.com/tmangan64/NixOSHome/main/deploy.sh | bash
#
#  Progress is saved so you can safely re-run at any point.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
fail()    { echo -e "${RED}${BOLD}[ERR ]${RESET}  $*" >&2; exit 1; }
ask()     { echo -en "${BOLD}${CYAN} >>> ${RESET}$* "; }
divider() { echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"; }
header()  { echo ""; divider; echo -e "${BOLD}$*${RESET}"; divider; }

# ── Progress & State ──────────────────────────────────────────────────────────
PROGRESS_FILE="/tmp/nixoshome_progress"
STATE_FILE="/tmp/nixoshome_state"

save_progress() { echo "STEP=$1" > "$PROGRESS_FILE"; }
load_progress() { [[ -f "$PROGRESS_FILE" ]] && source "$PROGRESS_FILE" || STEP=0; }
save_state() {
  declare -p WORKDIR SERVER_IP GATEWAY_IP GITHUB_USER GITHUB_REPO \
    SSH_KEY_PATH AGE_KEY_PATH AGE_PUB 2>/dev/null > "$STATE_FILE" || true
}
load_state() { [[ -f "$STATE_FILE" ]] && source "$STATE_FILE" || true; }

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

STEP_NAMES=("" "Configured" "Secrets encrypted" "NixOS installed" "Finalized")

if [[ "${STEP:-0}" -gt 0 ]]; then
  warn "Resuming from step ${STEP}: ${STEP_NAMES[$STEP]}"
  for i in 1 2 3 4; do
    if [[ $i -le $STEP ]]; then
      echo -e "  ${GREEN}✓${RESET} $i. ${STEP_NAMES[$i]}"
    elif [[ $i -eq $((STEP + 1)) ]]; then
      echo -e "  ${CYAN}→${RESET} $i. ${STEP_NAMES[$i]}"
    else
      echo -e "    $i. ${STEP_NAMES[$i]}"
    fi
  done
  echo ""
  read -rp "$(echo -e "${BOLD}Continue? [Y/n]: ${RESET}")" RESUME
  [[ "${RESUME,,}" == "n" ]] && { rm -f "$PROGRESS_FILE" "$STATE_FILE"; exec "$0"; }
else
  warn "This will ERASE /dev/nvme0n1 and install NixOS."
  read -rp "$(echo -e "${BOLD}Press ENTER to continue or Ctrl+C to abort...${RESET}")"
fi

# ── Bootstrap packages ────────────────────────────────────────────────────────
NEED_PKGS=()
for cmd in age sops ssh-to-age mkpasswd; do
  command -v "$cmd" &>/dev/null || NEED_PKGS+=("nixpkgs#$cmd")
done

if [[ ${#NEED_PKGS[@]} -gt 0 ]]; then
  info "Fetching tools: ${NEED_PKGS[*]}"
  SCRIPT_PATH="/tmp/nixoshome_deploy.sh"
  [[ -f "$0" && "$0" != "bash" ]] && cp "$0" "$SCRIPT_PATH" || \
    curl -sSL "https://raw.githubusercontent.com/tmangan64/NixOSHome/main/deploy.sh" -o "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  exec nix shell --extra-experimental-features "nix-command flakes" "${NEED_PKGS[@]}" \
    --command bash -c "exec < /dev/tty; $SCRIPT_PATH"
fi

export NIX_CONFIG="experimental-features = nix-command flakes"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Clone template & configure
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 1 ]]; then
  header "Step 1 — Configure"

  WORKDIR="$(mktemp -d)"
  info "Cloning template..."
  git clone https://github.com/tmangan64/NixOSHome.git "$WORKDIR/nixos" \
    || fail "Clone failed"
  cd "$WORKDIR/nixos"

  echo ""
  ask "Server IP address:"; read -r SERVER_IP
  [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Invalid IP"

  ask "Gateway IP address:"; read -r GATEWAY_IP
  [[ "$GATEWAY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Invalid gateway"

  ask "Your GitHub username:"; read -r GITHUB_USER
  [[ -n "$GITHUB_USER" ]] || fail "Required"

  ask "Your fork repo name [NixOSHome]:"; read -r GITHUB_REPO
  GITHUB_REPO="${GITHUB_REPO:-NixOSHome}"

  # SSH key
  SSH_KEY_PATH="$WORKDIR/admin_key"
  ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -q
  SSH_PUB="$(cat "${SSH_KEY_PATH}.pub")"
  success "SSH key generated"

  # Age key
  AGE_KEY_PATH="$WORKDIR/age.key"
  age-keygen -o "$AGE_KEY_PATH" 2>/dev/null
  AGE_PUB="$(age-keygen -y "$AGE_KEY_PATH")"
  success "Age key generated: ${AGE_PUB:0:30}..."

  # Write config.nix
  cat > config.nix <<EOF
{
  network.serverIP = "${SERVER_IP}";
  network.gateway  = "${GATEWAY_IP}";
  ssh.publicKey    = "${SSH_PUB}";
  github.username  = "${GITHUB_USER}";
  github.repo      = "${GITHUB_REPO}";
}
EOF
  success "config.nix written"

  # Patch .sops.yaml with age public key
  sed -i "s|&user_key age1[a-z0-9x]*|\\&user_key ${AGE_PUB}|" .sops.yaml
  grep -q "$AGE_PUB" .sops.yaml || fail "Failed to patch .sops.yaml"
  success ".sops.yaml patched"

  save_state
  save_progress 1
fi

cd "$WORKDIR/nixos"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 — Collect secrets & encrypt
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 2 ]]; then
  header "Step 2 — Secrets"

  ask "Admin password:"; read -rs ADMIN_PW; echo ""
  ask "Nextcloud admin password:"; read -rs NC_PW; echo ""

  ADMIN_HASH="$(echo "$ADMIN_PW" | mkpasswd -m sha-512 -s)"

  cat > secrets/secrets.yaml <<EOF
admin:
  password_hash: "${ADMIN_HASH}"
nextcloud:
  admin_password: "${NC_PW}"
EOF

  SOPS_AGE_KEY_FILE="$AGE_KEY_PATH" sops --encrypt --in-place \
    --age "$AGE_PUB" secrets/secrets.yaml \
    || fail "sops encrypt failed"

  unset ADMIN_PW NC_PW ADMIN_HASH
  success "Secrets encrypted"
  save_progress 2
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Install via nixos-anywhere
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 3 ]]; then
  header "Step 3 — Install NixOS"

  # Loopback SSH setup
  mkdir -p /root/.ssh
  cat "${SSH_KEY_PATH}.pub" > /root/.ssh/authorized_keys
  chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys
  systemctl start sshd 2>/dev/null || true
  sleep 2
  ssh-keyscan 127.0.0.1 >> ~/.ssh/known_hosts 2>/dev/null || true

  warn "This will ERASE /dev/nvme0n1"
  ask "Type YES to confirm:"; read -r CONFIRM
  [[ "$CONFIRM" == "YES" ]] || fail "Aborted"

  info "Running nixos-anywhere..."
  nix run github:nix-community/nixos-anywhere -- \
    --flake "$WORKDIR/nixos#homeserver" \
    --target-host root@127.0.0.1 \
    -i "$SSH_KEY_PATH" \
    || fail "nixos-anywhere failed"

  success "NixOS installed"
  save_progress 3

  warn "System will reboot. Re-run this script after boot to finalize."
  read -rp "$(echo -e "${BOLD}Press ENTER to reboot...${RESET}")"
  reboot
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Finalize: get host key, re-encrypt, push
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 4 ]]; then
  header "Step 4 — Finalize"

  info "Waiting for server at ${SERVER_IP}:2266..."
  until ssh-keyscan -p 2266 "$SERVER_IP" 2>/dev/null | grep -q ed25519; do
    sleep 5; echo -n "."
  done
  echo ""

  HOST_AGE="$(ssh-keyscan -p 2266 "$SERVER_IP" 2>/dev/null | grep ed25519 | ssh-to-age)"
  success "Host age key: ${HOST_AGE:0:30}..."

  # Patch host key into .sops.yaml
  sed -i "s|&host_homeserver age1[a-z0-9x]*|\\&host_homeserver ${HOST_AGE}|" .sops.yaml
  grep -q "$HOST_AGE" .sops.yaml || fail "Failed to patch host key"

  # Re-encrypt with both keys
  SOPS_AGE_KEY_FILE="$AGE_KEY_PATH" sops updatekeys -y secrets/secrets.yaml \
    || fail "sops updatekeys failed"
  success "Secrets re-encrypted with host key"

  # Push to user's fork
  info "Pushing to github.com/${GITHUB_USER}/${GITHUB_REPO}..."
  ask "GitHub Personal Access Token:"; read -rs GH_TOKEN; echo ""

  git remote set-url origin "https://${GITHUB_USER}:${GH_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
  git config user.email "deploy@nixos"; git config user.name "deploy.sh"
  git add -A
  git commit -m "Deploy configuration $(date +%Y-%m-%d)"
  git push -u origin main --force || fail "Push failed"
  unset GH_TOKEN
  success "Pushed to GitHub"

  # Rebuild on server
  info "Rebuilding server..."
  ssh -p 2266 -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "admin@${SERVER_IP}" \
    "sudo nixos-rebuild switch --flake github:${GITHUB_USER}/${GITHUB_REPO}#homeserver" \
    || fail "Rebuild failed"

  success "Server configured"
  save_progress 4
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Deployment complete!${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}SSH:${RESET}       ssh -p 2266 -i ${SSH_KEY_PATH} admin@${SERVER_IP}"
echo -e "${BOLD}AdGuard:${RESET}   https://${SERVER_IP}:3000"
echo -e "${BOLD}Nextcloud:${RESET} https://${SERVER_IP}"
echo ""
warn "Back up your SSH key: ${SSH_KEY_PATH}"
echo ""
