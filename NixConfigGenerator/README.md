# NixOS Config Generator

A self-contained Java Swing GUI application that generates complete NixOS configurations with SOPS-encrypted secrets for home server deployments.

## Project Overview

This tool streamlines the creation of NixOS configurations by:
1. Collecting server parameters through a GUI
2. Generating all necessary cryptographic keys (SSH, age)
3. Producing a complete, deployable NixOS flake configuration

The generated output is ready for deployment with `nixos-anywhere` and includes all SOPS-encrypted secrets.

## Features

- **Complete NixOS Configuration**: Generates all files needed for a home server deployment
- **Self-Contained Cryptography**: All operations done in Java with BouncyCastle:
  - Ed25519 SSH host key generation (OpenSSH format)
  - X25519 age key generation (bech32 encoded)
  - SSH-to-age key conversion
  - SHA-512 crypt password hashing
  - Age/SOPS encryption (ChaCha20-Poly1305)
- **GUI Interface**: Easy-to-use tabbed interface for configuration
- **Production-Ready Output**: Generates configs identical to production structure

## Prerequisites

- Java 17 or later
- Maven 3.6 or later (or use `nix-shell -p maven`)

## Building

```bash
cd NixConfigGenerator
mvn clean package
```

Or with Nix:
```bash
nix-shell -p maven --run "mvn clean package"
```

This creates a self-contained JAR file at `target/NixConfigGenerator-1.0.0.jar` (~8MB with dependencies).

## Running

```bash
java -jar target/NixConfigGenerator-1.0.0.jar
```

## Configuration Fields

### Network Tab
| Field | Description | Example |
|-------|-------------|---------|
| Hostname | Server hostname | `homeserver` |
| Domain | Local domain (creates dns.{domain}, nas.{domain}) | `home` |
| Network Interface | Network interface name | `enp3s0` |
| Static IP | Server's static IP address | `192.168.0.66` |
| Prefix Length | Network prefix (24 = 255.255.255.0) | `24` |
| Gateway | Default gateway | `192.168.0.1` |
| SSH Port | SSH server port (non-standard recommended) | `2266` |

### User Tab
| Field | Description |
|-------|-------------|
| Admin Username | Administrator account name |
| Admin Password | Password (hashed with SHA-512 crypt) |
| SSH Public Key | Your SSH public key for passwordless login |
| Nextcloud Password | Nextcloud admin password (encrypted with age) |

### System Tab
| Field | Description | Example |
|-------|-------------|---------|
| Timezone | System timezone | `Europe/London` |
| Locale | System locale | `en_GB.UTF-8` |
| Console Keymap | Console keyboard layout | `uk` |
| Phone Region | ISO 3166-1 alpha-2 code for Nextcloud | `GB` |
| GitHub Flake URL | Auto-upgrade flake URL | `github:user/repo#hostname` |

## Generated Output

```
output-folder/
├── flake.nix                 # Main flake configuration
├── .sops.yaml                # SOPS key configuration
├── hosts/{hostname}/
│   ├── configuration.nix     # Host configuration (boot, SSH, packages)
│   ├── hardware.nix          # Hardware configuration (CPU, modules)
│   └── disko.nix             # Disk layout (NVMe + SATA)
├── modules/
│   ├── users.nix             # User management with SOPS password
│   ├── networking.nix        # Static IP, firewall, DNS
│   ├── secrets.nix           # SOPS integration
│   ├── adguard.nix           # AdGuard Home DNS filtering
│   ├── caddy.nix             # Caddy reverse proxy
│   ├── nextcloud.nix         # Nextcloud with PostgreSQL + Redis
│   └── auto-upgrade.nix      # Automatic flake updates
├── secrets/
│   └── secrets.yaml          # SOPS-encrypted secrets
└── keys/
    ├── ssh_host_ed25519_key      # SSH host private key
    ├── ssh_host_ed25519_key.pub  # SSH host public key
    ├── age_key.txt               # Workstation age key
    └── host_age_public.txt       # Host age public key (reference)
```

## Workflow: Generated Config to Production

The generator produces a **TestConfig**-style output. To convert to production (**ActiveConfig**):

### Generated (TestConfig) vs Production (ActiveConfig)

| Aspect | Generated | Production |
|--------|-----------|------------|
| `keys/` directory | Included | Removed (stored securely elsewhere) |
| `flake.lock` | Not included | Added after first `nix flake update` |
| GitHub flake URL | Placeholder or custom | Real repository URL |
| Age keys | Freshly generated | Your actual deployment keys |
| Secrets | Encrypted with generated keys | Re-encrypted with production keys |

### Steps to Production

1. **Generate initial configuration** using the GUI

2. **Secure the keys**:
   ```bash
   chmod 700 output-folder/keys
   chmod 600 output-folder/keys/*
   ```

3. **Set up workstation age key**:
   ```bash
   mkdir -p ~/.config/sops/age
   cp output-folder/keys/age_key.txt ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

4. **Push to GitHub repository**:
   ```bash
   cd output-folder
   git init
   git add -A
   git commit -m "Initial NixOS configuration"
   git remote add origin git@github.com:user/repo.git
   git push -u origin main
   ```

5. **Update flake URL** in `modules/auto-upgrade.nix`:
   ```nix
   flake = "github:YOUR-USERNAME/YOUR-REPO#hostname";
   ```

6. **Deploy with nixos-anywhere**:
   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#hostname \
     --extra-files keys \
     root@target-ip
   ```

7. **Post-deployment**: Update `hardware.nix` with actual hardware config:
   ```bash
   ssh admin@server "nixos-generate-config --show-hardware-config"
   ```

8. **Remove keys from repo** (keep backup elsewhere):
   ```bash
   rm -rf keys/
   git add -A && git commit -m "Remove keys from repo"
   ```

## Services Included

| Service | Purpose | Port |
|---------|---------|------|
| **OpenSSH** | Hardened SSH with key-only auth | Custom (default 2266) |
| **AdGuard Home** | DNS filtering and ad blocking | 53 (DNS), 3000 (UI) |
| **Caddy** | Reverse proxy with internal TLS | 443 |
| **Nextcloud** | Self-hosted file storage | 8080 (internal) |
| **Fail2ban** | Brute-force protection | - |
| **PostgreSQL** | Database for Nextcloud | - |
| **Redis** | Caching for Nextcloud | - |

## Security Features

- **SSH**: Key-only authentication, root login disabled, non-standard port
- **Firewall**: Default-deny with explicit port allowlist
- **Secrets**: SOPS encryption with age (X25519 + ChaCha20-Poly1305)
- **Passwords**: SHA-512 crypt hashing (5000 rounds)
- **DNS**: Local AdGuard for privacy and ad blocking
- **TLS**: Internal certificates via Caddy for local services
- **Updates**: Automatic system upgrades from GitHub flake

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     NixOS Server                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌──────────────────────────────┐ │
│  │ AdGuard │  │  Caddy  │  │         Nextcloud            │ │
│  │  :53    │  │  :443   │──│  nginx:8080 + PostgreSQL     │ │
│  │  :3000  │  │         │  │  + Redis                     │ │
│  └─────────┘  └─────────┘  └──────────────────────────────┘ │
│       │            │                    │                   │
│       └────────────┴────────────────────┘                   │
│                         │                                   │
│  ┌──────────────────────┴───────────────────────────────┐   │
│  │                    SOPS Secrets                      │   │
│  │   Decrypted at boot via SSH host key → age          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
NixConfigGenerator/
├── pom.xml                           # Maven build with BouncyCastle
├── src/main/java/nixgen/
│   ├── Main.java                     # Entry point
│   ├── gui/
│   │   ├── MainFrame.java            # Tabbed window
│   │   ├── NetworkPanel.java         # Network form
│   │   ├── UserPanel.java            # Credentials form
│   │   ├── SystemPanel.java          # Timezone, locale
│   │   └── OutputPanel.java          # Directory selection
│   ├── model/
│   │   └── ConfigData.java           # Configuration POJO
│   ├── crypto/
│   │   ├── Bech32.java               # Bech32 encoding
│   │   ├── Ed25519KeyGen.java        # SSH key generation
│   │   ├── X25519KeyGen.java         # Age key generation
│   │   ├── SshToAge.java             # Ed25519 → X25519
│   │   ├── Sha512Crypt.java          # Password hashing
│   │   ├── AgeEncrypt.java           # ChaCha20-Poly1305
│   │   └── SopsYaml.java             # SOPS YAML generation
│   └── generator/
│       ├── ConfigGenerator.java      # Orchestrator
│       └── templates/                # Nix template classes
└── README.md
```

## License

MIT
