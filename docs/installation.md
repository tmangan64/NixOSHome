# Installation Guide

This guide walks you through deploying a NixOS home server using this configuration.

## Prerequisites

On your workstation, you need:

- **Git** - For cloning and version control
- **Nix** - With flakes enabled ([install instructions](https://nixos.org/download.html))
- **Python 3 with tkinter** - For the generator GUI
- **age** - For secret encryption (`nix-shell -p age`)
- **sops** - For secret management (`nix-shell -p sops`)
- **ssh-to-age** - For converting SSH keys (`nix-shell -p ssh-to-age`)

## Target Machine

Your target machine should have:

- Ubuntu Server installed (for nixos-anywhere), OR
- Booted from NixOS ISO, OR
- Existing NixOS installation

The machine needs:
- SSH access from your workstation
- An OS disk (will be formatted)
- A data disk/partition (should be pre-formatted with ext4)

## Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR_USER/NixOSHome.git
cd NixOSHome
```

## Step 2: Generate Configuration

Run the GUI generator:

```bash
cd generator
nix-shell --run "python nixgen.py"
```

Fill in all the fields:

1. **Host & Locale** - Hostname, timezone, language settings
2. **Network** - Static IP configuration
3. **SSH & User** - SSH port, public keys, passwords
4. **Services** - Nextcloud and AdGuard settings
5. **Disks** - OS disk and data partition paths

### Password Hash

Before generating, create your password hash:

```bash
mkpasswd -m sha-512
```

Enter your password when prompted, then paste the hash into the generator.

### SSH Keys

Get your SSH public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Paste it into the SSH Public Keys field.

Click **Generate** to create the configuration files.

## Step 3: Set Up SOPS Encryption

### Generate Your Age Key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

Note the public key (starts with `age1...`).

### Configure SOPS

```bash
cp flake/.sops.yaml.template flake/options/.sops.yaml
```

Edit `flake/options/.sops.yaml` and replace `<YOUR_AGE_PUBLIC_KEY>` with your age public key.

For now, comment out or remove the host key line (we'll add it after first deploy):

```yaml
keys:
  - &user_key age1abc123...your.public.key...
  # - &host_key <HOST_AGE_PUBLIC_KEY>  # Add after deploy

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *user_key
          # - *host_key  # Add after deploy
```

### Encrypt Secrets

```bash
cd flake/options
sops --encrypt --in-place secrets.yaml
```

The secrets.yaml file is now encrypted and safe to commit.

## Step 4: Initial Deploy with nixos-anywhere

### From Ubuntu Target

If the target is running Ubuntu:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#homeserver \
  root@TARGET_IP
```

### From NixOS ISO

If booted from NixOS ISO, first set a root password on the target:

```bash
# On target machine
sudo passwd
```

Then from your workstation:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#homeserver \
  root@TARGET_IP
```

Replace `homeserver` with your configured hostname and `TARGET_IP` with the target's IP address.

## Step 5: Add Host Key to SOPS

After the initial deploy, the host has generated SSH keys. We need to add the host's key to SOPS.

### Get the Host's Age Key

```bash
ssh -p YOUR_SSH_PORT admin@TARGET_IP \
  "sudo cat /etc/ssh/ssh_host_ed25519_key.pub" | ssh-to-age
```

Or scan from known_hosts:

```bash
ssh-keyscan -p YOUR_SSH_PORT TARGET_IP 2>/dev/null | ssh-to-age
```

### Update SOPS Configuration

Edit `flake/options/.sops.yaml` and add the host key:

```yaml
keys:
  - &user_key age1abc123...your.public.key...
  - &host_key age1xyz789...host.public.key...

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *user_key
          - *host_key
```

### Re-encrypt Secrets

```bash
cd flake/options
sops updatekeys secrets.yaml
```

## Step 6: Final Rebuild

The initial deploy may have failed to decrypt secrets (expected). Now rebuild with the host key configured:

SSH into the server:

```bash
ssh -p YOUR_SSH_PORT admin@TARGET_IP
```

Rebuild:

```bash
sudo nixos-rebuild switch --flake github:YOUR_USER/NixOSHome#homeserver
```

Or from your workstation:

```bash
nixos-rebuild switch --flake .#homeserver \
  --target-host admin@TARGET_IP \
  --use-remote-sudo
```

## Step 7: Verify Services

After successful rebuild, verify:

- **SSH**: `ssh -p PORT admin@IP`
- **AdGuard**: https://dns.home:443 (or your configured domain)
- **Nextcloud**: https://cloud.home (or your configured domain)

## Troubleshooting

### SOPS Decryption Fails

- Ensure the host's age key is in `.sops.yaml`
- Run `sops updatekeys secrets.yaml` after adding the host key
- Check that `/etc/ssh/ssh_host_ed25519_key` exists on the target

### Network Issues

- Verify the network interface name (`ip link show`)
- Check IP configuration matches your network
- Ensure the gateway is correct

### Services Not Starting

Check service status:

```bash
systemctl status nextcloud-setup
systemctl status adguardhome
systemctl status caddy
```

View logs:

```bash
journalctl -u SERVICE_NAME -f
```

## Next Steps

- See [deployment.md](deployment.md) for update procedures
- See [secrets-setup.md](secrets-setup.md) for advanced secrets configuration
