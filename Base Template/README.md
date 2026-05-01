# NixOS Home Server - Base Template

This is a template for deploying a declarative NixOS home server. The configuration uses a central `user-config.nix` file for all user-specific values, making it easy to customize for your environment.

## Quick Start

### 1. Run the Setup Script

```bash
./setup.sh
```

This interactive script will:
- Collect your system configuration (hostname, IP, timezone, etc.)
- Detect your hardware where possible
- Generate `user-config.nix` with your values
- Create `.sops.yaml` for secrets encryption
- Create a secrets template

### 2. Set Up Your Secrets

```bash
# Generate a password hash for your admin user
mkpasswd -m sha-512

# Copy and edit the secrets template
cp secrets/secrets.yaml.template secrets/secrets.yaml
vim secrets/secrets.yaml  # Add your secrets

# Encrypt the secrets file
sops -e -i secrets/secrets.yaml
```

### 3. Deploy to Your Server

Using nixos-anywhere for initial deployment:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#homeserver root@<target-ip>
```

### 4. Post-Deployment: Update Host Age Key

After first boot, get the server's age key and update your configuration:

```bash
# Get the server's age key
ssh-keyscan <server-ip> 2>/dev/null | ssh-to-age

# Update user-config.nix with the hostAgeKey value
# Update .sops.yaml with the new key

# Re-key secrets to include the host
sops updatekeys secrets/secrets.yaml
```

### 5. Apply Updates

For subsequent updates after the initial deployment:

```bash
nixos-rebuild switch --flake .#homeserver --target-host admin@<server-ip>
```

## File Structure

```
Base Template/
├── setup.sh                    # Interactive setup script
├── user-config.nix             # Your configuration values
├── flake.nix                   # Nix flake entry point
├── .sops.yaml                  # SOPS encryption config
├── hosts/
│   └── homeserver/
│       ├── configuration.nix   # Main system config
│       ├── disko.nix           # Disk partitioning
│       └── hardware.nix        # Hardware detection
├── modules/
│   ├── users.nix               # User accounts
│   ├── networking.nix          # Network configuration
│   ├── secrets.nix             # SOPS secrets setup
│   ├── caddy.nix               # Reverse proxy
│   ├── adguard.nix             # DNS filtering
│   ├── nextcloud.nix           # Cloud storage (optional)
│   ├── authentik.nix           # SSO/Identity (optional)
│   ├── wireguard.nix           # VPN (optional)
│   └── auto-upgrade.nix        # Auto updates (optional)
└── secrets/
    └── secrets.yaml            # Encrypted secrets
```

## Enabling Optional Modules

Edit `flake.nix` and uncomment the modules you want:

```nix
modules = [
  # ... core modules ...

  # Uncomment to enable:
  ./modules/nextcloud.nix
  ./modules/authentik.nix
  ./modules/wireguard.nix
  ./modules/auto-upgrade.nix
];
```

Remember to add the corresponding secrets for each module you enable.

## User Configuration Reference

The `user-config.nix` file contains all user-specific values:

| Field | Description | Example |
|-------|-------------|---------|
| `hostname` | Server hostname | `homeserver` |
| `domain` | Local domain suffix | `home` |
| `username` | Admin username | `admin` |
| `sshPublicKey` | Your SSH public key | `ssh-ed25519 AAAA...` |
| `timeZone` | System timezone | `Europe/London` |
| `locale` | System locale | `en_GB.UTF-8` |
| `networkInterface` | Network interface name | `enp3s0` |
| `ipAddress` | Static IP address | `192.168.1.100` |
| `prefixLength` | Network prefix (CIDR) | `24` |
| `gateway` | Default gateway | `192.168.1.1` |
| `diskDevice` | Target disk device | `/dev/nvme0n1` |
| `cpuVendor` | CPU vendor | `intel` or `amd` |
| `platform` | System architecture | `x86_64-linux` |
| `userAgeKey` | Your age public key | `age1...` |
| `hostAgeKey` | Server's age key | `age1...` |

## Services & Ports

Default services and their ports:

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| SSH | 22 | TCP | Secure shell access |
| AdGuard DNS | 53 | TCP/UDP | DNS filtering |
| Caddy HTTP | 80 | TCP | HTTP redirect |
| Caddy HTTPS | 443 | TCP | HTTPS reverse proxy |
| AdGuard Web UI | 3000 | TCP | Admin interface |
| Nextcloud | 8080 | TCP | Via Caddy at cloud.home |
| Authentik | 9000 | TCP | Via Caddy at auth.home |
| WireGuard | 51820 | UDP | VPN |

## Requirements

- Target machine: x86_64 or aarch64 Linux compatible
- Workstation: Nix with flakes enabled
- SSH key pair
- Age key for secrets encryption
