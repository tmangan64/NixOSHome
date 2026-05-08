# NixOS Home Server

A ready-to-deploy NixOS home server with Nextcloud, AdGuard Home, and security hardening.

## What You Get

- **Nextcloud** - Self-hosted cloud storage
- **AdGuard Home** - Network-wide DNS ad blocking
- **Caddy** - Automatic HTTPS reverse proxy
- **Fail2ban** - SSH brute-force protection
- **Automatic updates** - Daily rebuilds with security patches

## Prerequisites

**On your workstation:**
- Nix with flakes enabled
- Python 3 with tkinter (provided via nix-shell)

**Target machine:**
- SSH access (can be Ubuntu, NixOS ISO, or existing NixOS)
- OS disk (will be formatted)
- Data partition (should be pre-formatted with ext4)

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR_USER/NixOSHome.git
cd NixOSHome
```

---

## Step 2: Gather Required Information

Before running the generator, collect:

**From your workstation:**
```bash
# Your SSH public key
cat ~/.ssh/id_ed25519.pub
```

**From your target machine:**
```bash
# Network interface name
ip link show

# Disk devices
lsblk -d -o NAME,SIZE,MODEL
```

**Generate a password hash:**
```bash
nix-shell -p mkpasswd --run "mkpasswd -m sha-512"
```

---

## Step 3: Run the Generator

```bash
cd generator
nix-shell --run "python nixgen.py"
```

Fill in each tab:
1. **Host & Locale** - Hostname, timezone, language
2. **Network** - IP address, gateway, interface
3. **SSH & User** - SSH port, public key, password hash, Nextcloud password
4. **Services** - Nextcloud and AdGuard settings
5. **Disks** - OS disk and data partition paths

Click **Generate** to create `options/options.nix` and `options/secrets.yaml`.

---

## Step 4: Set Up Secret Encryption

### Create your age key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

Note your public key (starts with `age1...`).

### Configure SOPS

```bash
cp .sops.yaml.template options/.sops.yaml
```

Edit `options/.sops.yaml`:
```yaml
keys:
  - &user_key age1abc...  # Replace with YOUR public key

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *user_key
```

### Encrypt secrets

```bash
cd options
nix-shell -p sops --run "sops --encrypt --in-place secrets.yaml"
cd ..
```

---

## Step 5: Push to GitHub

Create a new repository on GitHub, then:

```bash
git remote set-url origin https://github.com/YOUR_USER/NixOSHome.git
git add .
git commit -m "Configure for my server"
git push
```

The encrypted secrets are safe to commit.

---

## Step 6: Deploy with nixos-anywhere

From your workstation, deploy to the target:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake github:YOUR_USER/NixOSHome#HOSTNAME \
  root@TARGET_IP
```

Replace:
- `YOUR_USER` - Your GitHub username
- `HOSTNAME` - The hostname you configured
- `TARGET_IP` - Target machine's current IP

**Note:** The first deploy will fail to decrypt secrets. This is expected.

---

## Step 7: Add Host Key to SOPS

After deployment, get the host's age key:

```bash
ssh-keyscan -p SSH_PORT TARGET_IP 2>/dev/null | nix-shell -p ssh-to-age --run ssh-to-age
```

Edit `options/.sops.yaml` to add the host key:

```yaml
keys:
  - &user_key age1abc...       # Your key
  - &host_key age1xyz...       # Add this line with the host's key

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *user_key
          - *host_key          # Add this line
```

Re-encrypt secrets with both keys:

```bash
cd options
nix-shell -p sops --run "sops updatekeys secrets.yaml"
cd ..
```

Commit and push:

```bash
git add options/.sops.yaml options/secrets.yaml
git commit -m "Add host key to SOPS"
git push
```

---

## Step 8: Final Rebuild

SSH into your server:

```bash
ssh -p SSH_PORT admin@TARGET_IP
```

Rebuild with the updated configuration:

```bash
sudo nixos-rebuild switch --flake github:YOUR_USER/NixOSHome#HOSTNAME
```

---

## Step 9: Verify Services

After successful rebuild:

- **SSH:** `ssh -p SSH_PORT admin@SERVER_IP`
- **AdGuard:** https://dns.home (or your configured domain)
- **Nextcloud:** https://cloud.home (or your configured domain)

Point your devices' DNS to the server's IP address to use AdGuard.

---

## Updating Your Server

After making changes, commit and push to GitHub. Then on the server:

```bash
sudo nixos-rebuild switch --flake github:YOUR_USER/NixOSHome#HOSTNAME
```

Or let automatic updates handle it (runs daily at 04:00).

---

## Troubleshooting

### SOPS decryption fails
- Verify the host key is in `options/.sops.yaml`
- Run `sops updatekeys secrets.yaml` after adding the host key
- Check `/etc/ssh/ssh_host_ed25519_key` exists on the server

### Network issues
- Verify interface name with `ip link show`
- Check IP/gateway match your network
- Ensure the data partition exists and is formatted

### Services not starting
```bash
systemctl status nextcloud-setup
systemctl status adguardhome
journalctl -u SERVICE_NAME -f
```

---

## Repository Structure

```
NixOSHome/
├── flake.nix                 # Main flake definition
├── .sops.yaml.template       # SOPS template (copy to options/)
├── config/                   # System configuration
│   ├── configuration.nix
│   ├── hardware.nix
│   └── disko.nix
├── modules/                  # Service modules
│   ├── users.nix
│   ├── networking.nix
│   ├── secrets.nix
│   ├── adguard.nix
│   ├── caddy.nix
│   ├── nextcloud.nix
│   └── auto-upgrade.nix
├── options/                  # Your configuration (generated)
│   ├── options.nix
│   ├── secrets.yaml
│   └── .sops.yaml
└── generator/                # Configuration generator
    ├── nixgen.py
    └── shell.nix
```
