# Home Server Flake

Declarative NixOS home server with AdGuard Home DNS and Caddy reverse proxy.

## Architecture

| Service | Hostname | Port (internal) | Notes |
|---|---|---|---|
| AdGuard Home | dns.home | 3000 | Network DNS resolver and ad blocker |
| Caddy | (frontend) | 80, 443 | Reverse proxy with internal CA |

All web services proxied through Caddy with `tls internal` (self-signed root CA generated on first start).

## Pre-deployment checklist

1. **Network interface**: In `modules/networking.nix`, replace `CHANGEME_INTERFACE` with your actual NIC name (run `ip link` on target)
2. **Generate secrets**: See below

## Generate age key and encrypt secrets

```bash
# Install sops and age if needed
nix-shell -p sops age

# Generate age keypair on your workstation
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
# Note the public key (age1...)

# Update .sops.yaml with your public key
# Replace age1CHANGEME_YOUR_AGE_PUBLIC_KEY with your actual key

# Generate admin password hash
mkpasswd -m sha-512
# Enter your desired password when prompted

# Create and encrypt secrets file
cp secrets/secrets.yaml.example secrets/secrets.yaml
sops secrets/secrets.yaml
# Paste the password hash into admin/password_hash
```

## Deploy with nixos-anywhere

From the Ubuntu environment on the target machine, enable SSH:

```bash
sudo systemctl enable --now ssh
ip a  # Note the IP address
```

From your workstation:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#homeserver \
  root@<TARGET_IP>
```

Disko will partition the disk, NixOS will install, system will reboot.

## Post-deploy

1. **Add server's age key to sops** (for future secret updates):
   ```bash
   ssh admin@192.168.0.66 "sudo cat /etc/ssh/ssh_host_ed25519_key.pub" | ssh-to-age
   ```
   Add this key to `.sops.yaml` and run `sops updatekeys secrets/secrets.yaml`

2. **Point router DNS** at 192.168.0.66 so devices use AdGuard

3. **Visit** `https://dns.home` to access AdGuard admin UI

4. **Install Caddy root cert** on client devices (optional, removes browser warnings):
   ```bash
   ssh admin@192.168.0.66 "sudo cat /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt"
   ```

## Updates

```bash
nixos-rebuild switch --flake .#homeserver --target-host admin@192.168.0.66 --use-remote-sudo
```

## Rollback

At the bootloader, select a previous generation. Or from a running system:
```bash
sudo nixos-rebuild switch --rollback
```
