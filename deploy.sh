#!/usr/bin/env bash
# =============================================================================
#  NixOS Home Server — Deploy Script
#  Run from a NixOS minimal live ISO:
#
#    curl -sSL https://raw.githubusercontent.com/<user>/<repo>/main/deploy.sh | bash
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
fail()    { echo -e "${RED}${BOLD}[ERR ]${RESET}  $*" >&2; exit 1; }
ask()     { echo -e "${BOLD}${CYAN} >>> ${RESET} $*"; }
divider() { echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"; }
header()  { echo ""; divider; echo -e "${BOLD}$*${RESET}"; divider; }

# Exit with instructions (doesn't clear console)
pause_for_user() {
  echo ""
  divider
  echo -e "${YELLOW}${BOLD}ACTION REQUIRED${RESET}"
  divider
  echo ""
  echo -e "$1"
  echo ""
  divider
  info "After completing the above, re-run this script to continue."
  info "Progress saved at step ${STEP}."
  echo ""
  exit 0
}

# ── Progress tracking ─────────────────────────────────────────────────────────
PROGRESS_FILE="/tmp/nixoshome_progress"
STATE_FILE="/tmp/nixoshome_state"

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

# ── Step names ────────────────────────────────────────────────────────────────
STEP_NAMES=(
  ""
  "Repository cloned & config.nix written"
  "Secrets configured"
  "NixOS installed"
  "Host key retrieved"
  "Complete"
)

# ── Resume notice ─────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -gt 0 ]]; then
  echo ""
  warn "Resuming from saved progress."
  info "Last completed step: ${STEP} — ${STEP_NAMES[$STEP]}"
  echo ""
  echo -e "  ${BOLD}Steps:${RESET}"
  for i in 1 2 3 4 5; do
    if [[ $i -le $STEP ]]; then
      echo -e "    ${GREEN}✓${RESET} $i. ${STEP_NAMES[$i]}"
    elif [[ $i -eq $((STEP + 1)) ]]; then
      echo -e "    ${CYAN}→${RESET} $i. ${STEP_NAMES[$i]}"
    else
      echo -e "      $i. ${STEP_NAMES[$i]}"
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

# ── Nix shell bootstrap ───────────────────────────────────────────────────────
REQUIRED_PKGS=(ssh-to-age mkpasswd)
MISSING_PKGS=()

for cmd in "${REQUIRED_PKGS[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING_PKGS+=("$cmd")
  fi
done

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
  info "Missing tools: ${MISSING_PKGS[*]}"
  info "Fetching required packages via nix shell..."
  echo ""

  SCRIPT_PATH="/tmp/nixoshome_deploy.sh"
  if [[ ! -f "$SCRIPT_PATH" ]] || [[ "$0" == "bash" ]] || [[ "$0" == "-bash" ]]; then
    curl -sSL "https://raw.githubusercontent.com/tmangan64/NixOSHome/main/deploy.sh" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
  elif [[ -f "$0" ]]; then
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
  fi

  exec nix shell \
    --extra-experimental-features "nix-command flakes" \
    nixpkgs#ssh-to-age nixpkgs#mkpasswd \
    --command bash -c "exec < /dev/tty; $SCRIPT_PATH"
fi

# ── Prerequisites ─────────────────────────────────────────────────────────────
for cmd in git nix ssh-keygen curl ssh-to-age; do
  if ! command -v "$cmd" &>/dev/null; then
    fail "Required tool not found: $cmd"
  fi
done

export NIX_CONFIG="experimental-features = nix-command flakes"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 — Clone repo & write config.nix
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 1 ]]; then
  header "Step 1 of 5 — Clone repository & configure"

  ask "Your GitHub username:"
  read -r GITHUB_USER
  [[ -n "$GITHUB_USER" ]] || fail "GitHub username cannot be empty."

  ask "Your fork's repository name [default: NixOSHome]:"
  read -r GITHUB_REPO
  GITHUB_REPO="${GITHUB_REPO:-NixOSHome}"

  REPO_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
  WORKDIR="$(mktemp -d)"

  info "Cloning your repository..."
  git clone "$REPO_URL" "$WORKDIR/nixoshome" \
    || fail "Clone failed. Ensure you have forked the repository."
  success "Cloned to $WORKDIR/nixoshome"
  echo ""

  ask "Static IP address for this server (e.g. 192.168.1.100):"
  read -r SERVER_IP
  [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "Invalid IP: $SERVER_IP"

  ask "Router / gateway IP address (e.g. 192.168.1.1):"
  read -r GATEWAY_IP
  [[ "$GATEWAY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "Invalid gateway: $GATEWAY_IP"

  info "Generating SSH key pair for admin access..."
  SSH_KEY_PATH="$WORKDIR/admin_ed25519"
  ssh-keygen -t ed25519 -C "nixoshome-admin" -f "$SSH_KEY_PATH" -N "" -q
  SSH_PUBLIC_KEY="$(cat "${SSH_KEY_PATH}.pub")"
  success "SSH key pair created."

  info "Writing config.nix..."
  cat > "$WORKDIR/nixoshome/config.nix" <<EOF
# User Configuration — generated by deploy.sh $(date +%Y-%m-%d)
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
# STEP 2 — Verify secrets are configured
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 2 ]]; then
  header "Step 2 of 5 — Verify secrets"

  # Check if secrets.yaml exists and is encrypted
  if [[ ! -f "secrets/secrets.yaml" ]]; then
    pause_for_user "$(cat <<'INSTRUCTIONS'
secrets/secrets.yaml not found. You need to create and encrypt it.

On your workstation (not this live USB):

1. Generate an age key (if you haven't already):
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt

2. Copy the PUBLIC key (starts with age1...) and update .sops.yaml:
   - Replace the placeholder in the &user_key line

3. Create secrets/secrets.yaml with your passwords:
   admin:
     password_hash: <output of: mkpasswd -m sha-512 "yourpassword">
   nextcloud:
     admin_password: your-nextcloud-password

4. Encrypt it:
   sops --encrypt --in-place secrets/secrets.yaml

5. Commit and push to your fork:
   git add .sops.yaml secrets/secrets.yaml
   git commit -m "Add encrypted secrets"
   git push
INSTRUCTIONS
)"
  fi

  # Check if it's actually encrypted (sops-encrypted files have a "sops:" key)
  if ! grep -q "^sops:" "secrets/secrets.yaml"; then
    pause_for_user "$(cat <<'INSTRUCTIONS'
secrets/secrets.yaml exists but is not encrypted.

On your workstation, encrypt it with:
  sops --encrypt --in-place secrets/secrets.yaml

Then commit and push to your fork.
INSTRUCTIONS
)"
  fi

  success "Secrets file found and encrypted."
  save_progress 2
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 — Install NixOS via nixos-anywhere
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 3 ]]; then
  header "Step 3 of 5 — Install NixOS"

  # Setup loopback SSH for nixos-anywhere
  info "Setting up loopback SSH..."
  mkdir -p /root/.ssh
  cp "${SSH_KEY_PATH}.pub" /root/.ssh/authorized_keys
  chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys
  systemctl start sshd 2>/dev/null || true
  sleep 2
  mkdir -p "$HOME/.ssh"
  ssh-keyscan -p 22 127.0.0.1 2>/dev/null >> "$HOME/.ssh/known_hosts" || true
  success "Loopback SSH ready."

  echo ""
  warn "About to partition and format /dev/nvme0n1."
  warn "The data drive /dev/sda1 will NOT be touched."
  echo ""
  read -rp "$(echo -e "${BOLD}Type YES to confirm: ${RESET}")" CONFIRM
  [[ "$CONFIRM" == "YES" ]] || fail "Installation cancelled."
  echo ""

  info "Running nixos-anywhere (this takes several minutes)..."
  nix run github:nix-community/nixos-anywhere -- \
    --flake "$WORKDIR/nixoshome#homeserver" \
    --target-host "root@127.0.0.1" \
    --ssh-option "StrictHostKeyChecking=no" \
    --ssh-option "IdentityFile=$SSH_KEY_PATH" \
    || fail "nixos-anywhere failed. Re-run this script to retry."

  success "NixOS installed."
  save_progress 3

  echo ""
  warn "The system will now reboot into the installed NixOS."
  warn "After it boots, re-run this script to complete setup."
  echo ""
  read -rp "$(echo -e "${BOLD}Press ENTER to reboot...${RESET}")"
  reboot
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 — Retrieve host age key
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${STEP:-0}" -lt 4 ]]; then
  header "Step 4 of 5 — Retrieve host age key"

  info "Waiting for server at ${SERVER_IP}:2266..."
  echo ""

  # Wait for server to come up
  for i in {1..30}; do
    if ssh-keyscan -p 2266 "$SERVER_IP" 2>/dev/null | grep -q ed25519; then
      break
    fi
    echo -n "."
    sleep 5
  done
  echo ""

  HOST_AGE_KEY="$(ssh-keyscan -p 2266 "$SERVER_IP" 2>/dev/null \
    | grep ed25519 \
    | ssh-to-age)" \
    || fail "Could not reach server at ${SERVER_IP}:2266. Is it booted?"

  success "Host age key retrieved."
  save_progress 4

  pause_for_user "$(cat <<INSTRUCTIONS
Add the server's age key to your repository so it can decrypt secrets.

Host age key:
  ${HOST_AGE_KEY}

On your workstation:

1. Edit .sops.yaml and add the host key:
   - Replace the placeholder in the &host_homeserver line with:
     ${HOST_AGE_KEY}

2. Re-encrypt secrets with both keys:
   sops updatekeys secrets/secrets.yaml

3. Commit and push:
   git add .sops.yaml secrets/secrets.yaml
   git commit -m "Add host age key"
   git push

4. SSH into the server and rebuild:
   ssh -p 2266 -i ${SSH_KEY_PATH} admin@${SERVER_IP}
   sudo nixos-rebuild switch --flake github:${GITHUB_USER}/${GITHUB_REPO}#homeserver
INSTRUCTIONS
)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 — Complete
# ─────────────────────────────────────────────────────────────────────────────
save_progress 5

echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  Deployment complete.${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}Services:${RESET}"
echo -e "  AdGuard Home  →  https://${SERVER_IP}:3000"
echo -e "  Nextcloud     →  https://${SERVER_IP}"
echo ""
echo -e "${BOLD}SSH access:${RESET}"
echo -e "  ssh -p 2266 -i ${SSH_KEY_PATH} admin@${SERVER_IP}"
echo ""
echo -e "${BOLD}Manual rebuild:${RESET}"
echo -e "  sudo nixos-rebuild switch --flake github:${GITHUB_USER}/${GITHUB_REPO}#homeserver"
echo ""
divider
info "SSH key: ${SSH_KEY_PATH} <- back this up!"
divider
echo ""
