# NixOS Config Generator

A Python CLI tool that generates complete NixOS flake configurations for home server deployments.

## Quick Start

```bash
# Enter development environment
nix-shell

# Run the generator
python nixgen.py
```

## Requirements

- Python 3.12+ with `cryptography` library
- `sops` and `age` tools for encrypting secrets
- `nix` for deployment

All dependencies are provided by `shell.nix`.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         YOUR WORKSTATION                                │
├─────────────────────────────────────────────────────────────────────────┤
│  1. python nixgen.py          → Creates output/ with config + secrets  │
│  2. sops -e -i secrets.yaml   → Encrypts secrets with age              │
│  3. Deploy to target          → nixos-anywhere / manual install        │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          TARGET SERVER                                  │
├─────────────────────────────────────────────────────────────────────────┤
│  - Receives NixOS configuration                                        │
│  - SSH host key used to decrypt SOPS secrets at boot                   │
│  - Runs AdGuard, Caddy, Nextcloud, etc.                                │
└─────────────────────────────────────────────────────────────────────────┘
```

## Step-by-Step Deployment

### Step 1: Generate Configuration (on YOUR WORKSTATION)

```bash
nix-shell
python nixgen.py
```

Follow the prompts to enter:
- Network settings (hostname, IP, gateway, SSH port)
- User credentials (admin username, password, SSH public key)
- System settings (timezone, locale)

This creates:
```
output/
├── flake.nix
├── .sops.yaml
├── hosts/homeserver/
│   ├── configuration.nix
│   ├── hardware.nix
│   └── disko.nix
├── modules/
│   ├── users.nix
│   ├── networking.nix
│   ├── secrets.nix
│   ├── adguard.nix
│   ├── caddy.nix
│   ├── nextcloud.nix
│   └── auto-upgrade.nix
├── secrets/
│   └── secrets.yaml          # UNENCRYPTED - must encrypt before commit!
└── keys/
    ├── age_key.txt           # Your workstation's age key
    ├── ssh_host_ed25519_key  # Server's SSH host key
    └── ssh_host_ed25519_key.pub
```

### Step 2: Encrypt Secrets (on YOUR WORKSTATION)

```bash
# Set up your age key for sops
mkdir -p ~/.config/sops/age
cp output/keys/age_key.txt ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# Encrypt the secrets file in-place
cd output
sops -e -i secrets/secrets.yaml
```

Verify encryption worked:
```bash
cat secrets/secrets.yaml  # Should show ENC[AES256_GCM,...] values
```

### Step 3: Deploy to Target Server

#### Option A: nixos-anywhere (Fresh Install)

**Run from YOUR WORKSTATION.** Target must be accessible via SSH (booted into NixOS installer or has SSH enabled).

```bash
cd output

# Deploy (this wipes the target disk!)
nix run github:nix-community/nixos-anywhere -- \
  --flake .#homeserver \
  root@<target-ip>
```

#### Option B: Manual Install from NixOS ISO

**Step 3a: Copy config (from YOUR WORKSTATION)**
```bash
scp -r output/ nixos@<target-ip>:/tmp/config
```

**Step 3b: Install (on TARGET SERVER, booted from NixOS ISO)**
```bash
# Partition disks using disko
sudo nix --experimental-features "nix-command flakes" run \
  github:nix-community/disko -- --mode disko /tmp/config/hosts/homeserver/disko.nix

# Install NixOS
sudo nixos-install --flake /tmp/config#homeserver

# Copy SSH host key (if using the generated one)
sudo cp /tmp/config/keys/ssh_host_ed25519_key* /mnt/etc/ssh/

reboot
```

#### Option C: Update Existing NixOS System

**Step 3a: Copy config (from YOUR WORKSTATION)**
```bash
scp -r output/ admin@<target-ip>:/tmp/config
```

**Step 3b: Apply config (on TARGET SERVER)**
```bash
sudo cp -r /tmp/config/* /etc/nixos/
sudo nixos-rebuild switch --flake /etc/nixos#homeserver
```

### Step 4: Post-Deployment

**Update hardware.nix (on TARGET SERVER or from WORKSTATION via SSH):**
```bash
# Generate actual hardware config
ssh admin@<server-ip> "nixos-generate-config --show-hardware-config" > output/hosts/homeserver/hardware.nix
```

**Push to Git (on YOUR WORKSTATION):**
```bash
cd output

# Remove keys before committing (keep backup!)
cp -r keys/ ~/nixos-keys-backup/
rm -rf keys/

git init
git add -A
git commit -m "Initial NixOS configuration"
git remote add origin git@github.com:user/repo.git
git push -u origin main
```

## Configuration Fields

| Field | Description | Example |
|-------|-------------|---------|
| Hostname | Server hostname | `homeserver` |
| Domain | Local domain (creates dns.{domain}, nas.{domain}) | `home` |
| Network Interface | NIC name (check with `ip link`) | `enp3s0` |
| Static IP | Server's IP address | `192.168.0.66` |
| Prefix Length | Subnet mask (24 = /24 = 255.255.255.0) | `24` |
| Gateway | Router IP | `192.168.0.1` |
| SSH Port | SSH port (non-standard recommended) | `2266` |
| Admin Username | Your admin account | `admin` |
| Admin Password | Login password (hashed with SHA-512) | |
| SSH Public Key | Your public key for passwordless SSH | `ssh-ed25519 AAAA...` |
| Nextcloud Password | Nextcloud admin password | |
| Timezone | System timezone | `Europe/London` |
| Locale | System locale | `en_GB.UTF-8` |
| Console Keymap | Keyboard layout | `uk` |
| Phone Region | ISO 3166-1 for Nextcloud | `GB` |
| GitHub Flake URL | For auto-upgrades (optional) | `github:user/repo#homeserver` |

## Services Included

| Service | Purpose | Access |
|---------|---------|--------|
| OpenSSH | Remote access (key-only) | Port from config |
| AdGuard Home | DNS filtering + ad blocking | dns.{domain} |
| Caddy | Reverse proxy with auto-TLS | HTTPS |
| Nextcloud | File storage | nas.{domain} |
| PostgreSQL | Nextcloud database | Internal |
| Redis | Nextcloud cache | Internal |
| Fail2ban | Brute-force protection | - |

## Keys Explained

| Key | Location | Purpose |
|-----|----------|---------|
| `age_key.txt` | Your workstation `~/.config/sops/age/keys.txt` | Decrypt/edit secrets |
| `ssh_host_ed25519_key` | Server `/etc/ssh/` | Server identity + SOPS decryption |
| Your SSH public key | Server `~/.ssh/authorized_keys` | Passwordless SSH login |

**Important:** The server decrypts SOPS secrets at boot using its SSH host key (converted to age format). This is configured in `.sops.yaml`.

## Editing Secrets After Deployment

On YOUR WORKSTATION (with age_key.txt in place):
```bash
cd /path/to/nixos-config
sops secrets/secrets.yaml  # Opens decrypted in $EDITOR, re-encrypts on save
git add -A && git commit -m "Update secrets" && git push
```

On TARGET SERVER:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#homeserver
# Or if using auto-upgrade, just wait for the next update cycle
```

## License

MIT
