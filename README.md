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
- Bootable NixOS live USB
- OS disk (will be formatted)
- Data partition (should be pre-formatted with ext4)

---

## Step 1: Create a NixOS Live USB

Download the NixOS minimal ISO from [nixos.org/download](https://nixos.org/download/#nixos-iso) and flash it to a USB drive:

```bash
# Replace /dev/sdX with your USB device
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot your target machine from the USB.

---

## Step 2: Prepare the Live Environment

On the target machine (booted from NixOS USB), set a password for the nixos user and start SSH:

```bash
# Set password for nixos user
passwd

# SSH daemon is already running, verify it
systemctl status sshd

# Get the IP address
ip addr
```

Note the IP address - you'll need it to SSH in from your workstation.

---

## Step 3: Clone the Repository (on workstation)

```bash
git clone https://github.com/YOUR_USER/NixOSHome.git
cd NixOSHome
```

---

## Step 4: Gather Required Information

**From your workstation:**
```bash
# Your SSH public key
cat ~/.ssh/id_ed25519.pub
```

**From your target machine (via SSH or directly):**
```bash
ssh nixos@TARGET_IP

# Network interface name (for permanent install)
ip link show

# Disk devices
lsblk -d -o NAME,SIZE,MODEL
```

**Generate a password hash (on workstation):**
```bash
nix-shell -p mkpasswd --run "mkpasswd -m sha-512"
```

---

## Step 5: Create Your Age Key

Generate an age key for encrypting secrets:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

Copy your public key (starts with `age1...`) - you'll need it for the generator.

---

## Step 6: Run the Generator

```bash
cd generator
nix-shell --run "python nixgen.py"
```

Fill in each tab:
1. **Host & Locale** - Hostname, timezone, language
2. **Network** - IP address, gateway, interface
3. **SSH & User** - SSH port, public key, password hash, Nextcloud password, age public key
4. **Services** - Nextcloud and AdGuard settings
5. **Disks** - OS disk and data partition paths

Click **Generate** to create the configuration files.

---

## Step 7: Encrypt Secrets

```bash
cd options
nix-shell -p sops --run "sops --encrypt --in-place secrets.yaml"
cd ..
```

---

## Step 8: Push to GitHub

Create a new repository on GitHub, then:

```bash
git remote set-url origin https://github.com/YOUR_USER/NixOSHome.git
git add .
git commit -m "Configure for my server"
git push
```

The encrypted secrets are safe to commit.

---

## Step 9: Deploy with nixos-anywhere

From your workstation, deploy to the target (still running the live USB):

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake github:YOUR_USER/NixOSHome#HOSTNAME \
  nixos@TARGET_IP
```

Replace:
- `YOUR_USER` - Your GitHub username
- `HOSTNAME` - The hostname you configured
- `TARGET_IP` - Target machine's IP (from Step 2)

Enter the password you set in Step 2 when prompted.

**Note:** The first deploy will fail to decrypt secrets. This is expected.

---

## Step 10: Add Host Key to SOPS

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

## Step 11: Final Rebuild

SSH into your server (now running from disk, not USB):

```bash
ssh -p SSH_PORT admin@TARGET_IP
```

Rebuild with the updated configuration:

```bash
sudo nixos-rebuild switch --flake github:YOUR_USER/NixOSHome#HOSTNAME
```

---

## Step 12: Verify Services

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

### SSH connection refused on live USB
- Verify SSH is running: `systemctl status sshd`
- Check firewall: `sudo iptables -L`
- Ensure you set a password with `passwd`

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
├── options/                  # Created by generator
│   ├── options.nix
│   ├── secrets.yaml
│   └── .sops.yaml
└── generator/                # Configuration generator
    ├── nixgen.py
    └── shell.nix
```
