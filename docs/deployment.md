# Deployment Guide

This guide covers deploying and updating your NixOS home server.

## Initial Deployment

### Using nixos-anywhere

nixos-anywhere can deploy to any machine with SSH access, even if it's running a different Linux distribution.

#### Prerequisites

- Target machine accessible via SSH
- Root or sudo access on target
- Nix installed on your workstation with flakes enabled

#### From Ubuntu Server

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#HOSTNAME \
  root@TARGET_IP
```

#### From NixOS ISO

Boot the target from NixOS minimal ISO, then set root password:

```bash
# On target
sudo passwd
```

Then deploy:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#HOSTNAME \
  root@TARGET_IP
```

#### From Existing NixOS

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#HOSTNAME \
  root@TARGET_IP
```

### Manual Installation

If nixos-anywhere doesn't work, you can install manually.

#### 1. Boot NixOS ISO

Boot the target from NixOS minimal ISO.

#### 2. Set Up Network (if needed)

```bash
# For DHCP
sudo systemctl start dhcpcd

# Or configure manually
sudo ip addr add IP_ADDRESS/PREFIX dev INTERFACE
sudo ip route add default via GATEWAY
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
```

#### 3. Partition Disks

Use disko to partition:

```bash
sudo nix run github:nix-community/disko -- \
  --mode disko \
  --flake github:YOUR_USER/NixOSHome#HOSTNAME
```

#### 4. Install NixOS

```bash
sudo nixos-install --flake github:YOUR_USER/NixOSHome#HOSTNAME
```

#### 5. Reboot

```bash
sudo reboot
```

## Updating an Existing System

### From the Server

SSH into the server:

```bash
ssh -p SSH_PORT admin@SERVER_IP
```

Update and rebuild:

```bash
sudo nixos-rebuild switch --flake github:YOUR_USER/NixOSHome#HOSTNAME
```

### From Your Workstation

Using remote deployment:

```bash
nixos-rebuild switch --flake .#HOSTNAME \
  --target-host admin@SERVER_IP \
  --use-remote-sudo
```

### Automatic Updates

The configuration includes automatic updates. By default:

- Updates run daily at 04:00
- Reboots automatically if kernel updates require it
- Pulls latest nixpkgs and rebuilds

To check auto-upgrade status:

```bash
systemctl status nixos-upgrade.timer
systemctl status nixos-upgrade.service
```

To trigger an immediate update:

```bash
sudo systemctl start nixos-upgrade.service
```

## Rollback

### Boot Menu Rollback

At boot, use the systemd-boot menu to select a previous generation.

### Command Line Rollback

List generations:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Rollback to previous:

```bash
sudo nixos-rebuild switch --rollback
```

Switch to specific generation:

```bash
sudo nix-env --switch-generation NUMBER --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

## Testing Changes

### Build Without Activating

Test that the configuration builds:

```bash
nixos-rebuild build --flake .#HOSTNAME
```

### Dry Run

See what would change:

```bash
nixos-rebuild dry-activate --flake .#HOSTNAME
```

### Test in VM

Build a VM to test:

```bash
nixos-rebuild build-vm --flake .#HOSTNAME
./result/bin/run-HOSTNAME-vm
```

## Updating Options

1. Edit `flake/options/options.nix` with new values
2. Commit and push to GitHub
3. Rebuild on server:

```bash
sudo nixos-rebuild switch --flake github:YOUR_USER/NixOSHome#HOSTNAME
```

## Updating Secrets

1. Decrypt secrets locally:

```bash
cd flake/options
sops secrets.yaml
```

2. Edit the values
3. Save and close (SOPS re-encrypts automatically)
4. Commit and push
5. Rebuild on server

## Updating Flake Inputs

To update nixpkgs and other inputs:

```bash
cd flake
nix flake update
```

Commit the updated `flake.lock` and rebuild.
