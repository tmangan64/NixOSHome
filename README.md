# NixOS Home Server

A minimal, declarative NixOS configuration for a home server. Designed for the Beelink ME Pro but adaptable to similar hardware.

## Features

- AdGuard Home - Network-wide DNS with ad blocking and DoH upstream
- Nextcloud - Self-hosted file storage and sync
- Caddy - Reverse proxy with automatic internal HTTPS
- SOPS - Encrypted secrets management with age
- Auto-upgrades - Automatic daily updates from your GitHub repository
- Fail2ban - SSH brute-force protection
- Hardened SSH - Key-only authentication on non-standard port

Important note: Default SSH port is `2266`
This can be changed but ensure it is changed throughout entire config

## Quick Start

1. Edit `config.nix` with your settings
2. Edit `.sops.yaml` with your age keys
3. Create and encrypt your secrets
4. Deploy to your server

## Configuration

### config.nix

Edit this file with your specific values:

```nix
{
  network = {
    serverIP = "192.168.1.100";    # Static IP for your server
    gateway = "192.168.1.1";       # Your router's IP
  };

  ssh = {
    publicKey = "ssh-ed25519 AAAA... user@host";
  };

  github = {
    username = "your-username";    # For auto-upgrades
    repo = "NixOSHome";
  };
}
```

### How to Obtain Your Values

#### Network Settings

**Server IP:** Choose an unused static IP on your network.

```bash
# Check your current network range
ip route | grep default
# Example output: default via 192.168.1.1 dev eth0
# Your server IP should be in the same range, e.g., 192.168.1.100
```

**Gateway:** Your router's IP address (shown in the command above).

> **Tip:** Reserve your chosen IP in your router's DHCP settings to prevent conflicts.

#### SSH Public Key

If you don't have an SSH key:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

View your public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the entire line (starts with `ssh-ed25519`).

#### GitHub Settings

- **username:** Your GitHub username
- **repo:** The name of your fork of this repository

## Secrets Setup

### 1. Generate Your Age Key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

Note the public key (starts with `age1...`).

### 2. Edit .sops.yaml

Replace the placeholder in `.sops.yaml` with your age public key:

```yaml
keys:
  - &user_key age1your_actual_public_key_here
  - &host_homeserver age1xxxxxxxxxx # Add after first boot
```

### 3. Create secrets.yaml

```bash
cp secrets/secrets.yaml.template secrets/secrets.yaml
```

Edit `secrets/secrets.yaml` with your values:

```yaml
admin:
  password_hash: <your-hashed-password>
nextcloud:
  admin_password: <your-nextcloud-password>
```

Generate a password hash:

```bash
mkpasswd -m sha-512
```

### 4. Encrypt Your Secrets

```bash
sops -e -i secrets/secrets.yaml
```

### 5. After First Boot

Get the server's host key and add it to `.sops.yaml`:

```bash
ssh-keyscan -p 2266 <server-ip> 2>/dev/null | grep ed25519 | ssh-to-age
```

Then re-encrypt secrets with both keys:

```bash
sops updatekeys secrets/secrets.yaml
```

## Installation

### Prerequisites

On your local machine, install:

- `nix` with flakes enabled
- `nixos-anywhere` (for remote installation)
- `age` and `sops` (for secrets)

```bash
# Install nixos-anywhere
nix profile install github:nix-community/nixos-anywhere
```

### Option A: From Any Linux Live ISO (Recommended)

This method works with Ubuntu, Fedora, or any Linux live environment with SSH.

#### 1. Boot the Target Machine

Boot your server from a live USB (Ubuntu Desktop recommended for ease of use).

#### 2. Enable SSH on the Live System

**Ubuntu/Debian:**

```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl start ssh
```

**Fedora:**

```bash
sudo dnf install -y openssh-server
sudo systemctl start sshd
```

#### 3. Set a Temporary Root Password

```bash
sudo passwd
# Or allow your SSH key:
mkdir -p ~/.ssh
echo "your-ssh-public-key" >> ~/.ssh/authorized_keys
sudo cp -r ~/.ssh /root/
```

#### 4. Find the IP Address

```bash
ip addr show
```

#### 5. Deploy from Your Local Machine

```bash
nixos-anywhere --flake .#homeserver root@<live-system-ip>
```

This will:

- Partition the disk (erases everything!)
- Install NixOS with your configuration
- Reboot into the new system

### Option B: From NixOS Minimal ISO

#### 1. Boot the NixOS ISO

Download from https://nixos.org/download and boot your server from it.

#### 2. Set Up Networking

The ISO usually gets DHCP automatically. Verify:

```bash
ip addr show
```

#### 3. Set Root Password for SSH

```bash
passwd
```

#### 4. Start SSH

```bash
systemctl start sshd
```

#### 5. Deploy from Your Local Machine

```bash
nixos-anywhere --flake .#homeserver root@<nixos-iso-ip>
```

### Option C: Manual Installation from NixOS ISO

If you prefer manual installation:

#### 1. Partition the Disk

```bash
# Clone your repo
nix-shell -p git
git clone https://github.com/YOUR_USERNAME/NixOSHome.git
cd NixOSHome

# Run disko to partition
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/homeserver/disko.nix
```

#### 2. Install NixOS

```bash
# Mount should already be done by disko at /mnt

# Copy your config
sudo mkdir -p /mnt/etc/nixos
sudo cp -r ./* /mnt/etc/nixos/

# Install
sudo nixos-install --flake /mnt/etc/nixos#homeserver
```

#### 3. Reboot

```bash
reboot
```

## Post-Installation

### Accessing Your Server

```bash
ssh -p 2266 admin@<server-ip>
```

### Accessing Services

Add DNS entries to your router or use the server as your DNS:

| Service      | URL                   |
| ------------ | --------------------- |
| AdGuard Home | https://dns.home:3000 |
| Nextcloud    | https://nas.home      |

### Trust the Internal CA

Caddy generates self-signed certificates. To avoid browser warnings:

1. Export the CA from the server:

   ```bash
   sudo cat /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt
   ```

2. Import it into your browser/system as a trusted CA.

## Maintenance

### Manual Update

```bash
sudo nixos-rebuild switch --flake github:YOUR_USERNAME/NixOSHome#homeserver
```

### Rollback

```bash
# List generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous
sudo nixos-rebuild switch --rollback

# Or boot into a previous generation from the bootloader
```

### View Logs

```bash
journalctl -u adguardhome
journalctl -u nextcloud-setup
journalctl -u caddy
```

## File Structure

```
.
├── config.nix           # Your configuration - edit this
├── .sops.yaml           # Age keys for secrets - edit this
├── flake.nix            # Flake definition
├── secrets/
│   ├── secrets.yaml.template
│   └── secrets.yaml     # Your encrypted secrets (create this)
├── hosts/homeserver/
│   ├── configuration.nix
│   ├── disko.nix        # Disk partitioning
│   └── hardware.nix     # Hardware-specific config
└── modules/
    ├── adguard.nix
    ├── auto-upgrade.nix
    ├── caddy.nix
    ├── networking.nix
    ├── nextcloud.nix
    ├── secrets.nix
    └── users.nix
```

## Troubleshooting

### Can't SSH after installation

- Verify your SSH key in `config.nix` is correct
- Check the server is accessible: `ping <server-ip>`
- Ensure port 2266 is not blocked by your network

### Services not accessible

- Verify DNS resolution: `dig @<server-ip> nas.home`
- Check service status: `systemctl status nextcloud-setup`
- Review logs: `journalctl -xe`

### Secrets decryption fails

- Ensure `.sops.yaml` has the correct age keys
- Verify the server's host key is added after first boot
- Re-encrypt: `sops updatekeys secrets/secrets.yaml`

## License

MIT
