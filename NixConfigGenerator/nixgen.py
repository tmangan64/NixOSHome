#!/usr/bin/env python3
"""
NixOS Config Generator - Simple Python version
Generates NixOS flake configurations for home servers.

Dependencies: cryptography (pip install cryptography)
"""

import secrets
import hashlib
import base64
from datetime import datetime, timezone
from dataclasses import dataclass
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives import serialization


@dataclass
class Config:
    hostname: str = "homeserver"
    domain: str = "home"
    network_interface: str = "enp3s0"
    static_ip: str = "192.168.0.66"
    prefix_length: int = 24
    gateway: str = "192.168.0.1"
    ssh_port: int = 2266
    admin_username: str = "admin"
    admin_password: str = ""
    admin_ssh_pubkey: str = ""
    nextcloud_password: str = ""
    timezone: str = "Europe/London"
    locale: str = "en_GB.UTF-8"
    keymap: str = "uk"
    phone_region: str = "GB"
    flake_url: str = ""

    @property
    def dns_domain(self) -> str:
        return f"dns.{self.domain}"

    @property
    def nas_domain(self) -> str:
        return f"nas.{self.domain}"


# === Bech32 encoding (for age keys) ===

BECH32_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

def bech32_polymod(values):
    GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    chk = 1
    for v in values:
        b = chk >> 25
        chk = ((chk & 0x1ffffff) << 5) ^ v
        for i in range(5):
            chk ^= GEN[i] if ((b >> i) & 1) else 0
    return chk

def bech32_hrp_expand(hrp):
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]

def bech32_create_checksum(hrp, data):
    values = bech32_hrp_expand(hrp) + data
    polymod = bech32_polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
    return [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]

def bech32_encode(hrp, data_bytes):
    """Encode data as Bech32. Format: <hrp>1<data><checksum>"""
    data = convertbits(data_bytes, 8, 5, True)
    checksum = bech32_create_checksum(hrp, data)
    return hrp + '1' + ''.join(BECH32_CHARSET[d] for d in data + checksum)

def convertbits(data, frombits, tobits, pad=True):
    acc, bits, ret = 0, 0, []
    maxv = (1 << tobits) - 1
    for value in data:
        acc = (acc << frombits) | value
        bits += frombits
        while bits >= tobits:
            bits -= tobits
            ret.append((acc >> bits) & maxv)
    if pad and bits:
        ret.append((acc << (tobits - bits)) & maxv)
    return ret


# === SHA-512 Crypt (password hashing) ===

B64_CHARS = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

def sha512_crypt(password: str, salt: str = None, rounds: int = 5000) -> str:
    if salt is None:
        salt = ''.join(secrets.choice(B64_CHARS) for _ in range(16))

    pwd = password.encode('utf-8')
    salt_bytes = salt.encode('utf-8')

    # Step 1-8: Compute digest B
    ctx_b = hashlib.sha512()
    ctx_b.update(pwd + salt_bytes + pwd)
    digest_b = ctx_b.digest()

    # Step 9-12: Compute digest A
    ctx_a = hashlib.sha512()
    ctx_a.update(pwd + salt_bytes)

    key_len = len(pwd)
    i = key_len
    while i > 64:
        ctx_a.update(digest_b)
        i -= 64
    ctx_a.update(digest_b[:i if i else 64])

    i = key_len
    while i > 0:
        if i & 1:
            ctx_a.update(digest_b)
        else:
            ctx_a.update(pwd)
        i >>= 1
    digest_a = ctx_a.digest()

    # Step 13-15: Compute DP
    ctx_dp = hashlib.sha512()
    for _ in range(key_len):
        ctx_dp.update(pwd)
    dp_full = ctx_dp.digest()
    dp = bytes(dp_full[i % 64] for i in range(key_len))

    # Step 16-18: Compute DS
    ctx_ds = hashlib.sha512()
    for _ in range(16 + digest_a[0]):
        ctx_ds.update(salt_bytes)
    ds_full = ctx_ds.digest()
    ds = bytes(ds_full[i % 64] for i in range(len(salt_bytes)))

    # Step 19-20: Rounds
    digest = digest_a
    for r in range(rounds):
        ctx = hashlib.sha512()
        if r & 1:
            ctx.update(dp)
        else:
            ctx.update(digest)
        if r % 3:
            ctx.update(ds)
        if r % 7:
            ctx.update(dp)
        if r & 1:
            ctx.update(digest)
        else:
            ctx.update(dp)
        digest = ctx.digest()

    # Encode result
    perm = [42,21,0,1,43,22,23,2,44,45,24,3,4,46,25,26,5,47,48,27,6,7,49,28,
            29,8,50,51,30,9,10,52,31,32,11,53,54,33,12,13,55,34,35,14,56,57,
            36,15,16,58,37,38,17,59,60,39,18,19,61,40,41,20,62,63]

    result = []
    for i in range(0, 63, 3):
        b0 = digest[perm[i]]
        b1 = digest[perm[i + 1]]
        b2 = digest[perm[i + 2]]
        value = b0 | (b1 << 8) | (b2 << 16)
        result.extend(B64_CHARS[(value >> (6 * j)) & 0x3f] for j in range(4))

    last = digest[perm[63]]
    result.append(B64_CHARS[last & 0x3f])
    result.append(B64_CHARS[(last >> 6) & 0x3f])

    return f"$6${salt}${''.join(result)}"


# === Ed25519 SSH Key Generation ===

def generate_ssh_ed25519_key(comment: str = "") -> tuple[str, str]:
    """Generate Ed25519 SSH key pair. Returns (private_key_pem, public_key_line)."""
    private_key = Ed25519PrivateKey.generate()
    public_key = private_key.public_key()

    # Private key in OpenSSH format
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.OpenSSH,
        encryption_algorithm=serialization.NoEncryption()
    ).decode('utf-8')

    # Public key in OpenSSH format
    public_ssh = public_key.public_bytes(
        encoding=serialization.Encoding.OpenSSH,
        format=serialization.PublicFormat.OpenSSH
    ).decode('utf-8')

    if comment:
        public_ssh = f"{public_ssh} {comment}"

    return private_pem, public_ssh, private_key, public_key


# === X25519 Age Key Generation ===

def generate_age_key() -> tuple[str, str, X25519PrivateKey]:
    """Generate age X25519 key pair. Returns (private_key_line, public_key_bech32, private_key_obj)."""
    private_key = X25519PrivateKey.generate()
    public_key = private_key.public_key()

    private_bytes = private_key.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption()
    )
    public_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )

    private_bech32 = bech32_encode("age-secret-key-", private_bytes).upper()
    public_bech32 = bech32_encode("age", public_bytes)

    timestamp = datetime.now(timezone.utc).isoformat()
    key_file = f"# created: {timestamp}\n# public key: {public_bech32}\n{private_bech32}\n"

    return key_file, public_bech32, private_key


def ed25519_to_x25519_pub(ed25519_public_key) -> str:
    """Convert Ed25519 public key to X25519/age format using birational map."""
    # Get raw Ed25519 public key bytes
    pub_bytes = ed25519_public_key.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )

    # Ed25519 public key is y-coordinate on Edwards curve
    # Clear sign bit and convert to integer (little-endian)
    y_bytes = bytearray(pub_bytes)
    y_bytes[31] &= 0x7f
    y = int.from_bytes(y_bytes, 'little')

    # Field prime p = 2^255 - 19
    p = (1 << 255) - 19

    # Birational map: u = (1 + y) / (1 - y) mod p
    numerator = (1 + y) % p
    denominator = (1 - y) % p
    u = (numerator * pow(denominator, -1, p)) % p

    # Convert back to bytes (little-endian)
    x25519_pub_bytes = u.to_bytes(32, 'little')

    return bech32_encode("age", x25519_pub_bytes)


# === Plaintext Secrets (user encrypts with sops) ===

def generate_plaintext_secrets(password_hash: str, nextcloud_password: str) -> str:
    """Generate plaintext secrets.yaml for user to encrypt with sops."""
    return f"""admin:
    password_hash: {password_hash}
nextcloud:
    admin_password: {nextcloud_password}
"""


# === Key Generator Class ===

class KeyGenerator:
    def __init__(self, output_dir: Path, hostname: str):
        self.output_dir = output_dir
        self.hostname = hostname
        self.keys_dir = output_dir / "keys"
        self.keys_dir.mkdir(parents=True, exist_ok=True)

        self.user_age_pubkey = ""
        self.host_age_pubkey = ""
        self._ssh_private_key = None
        self._ssh_public_key = None

    def generate_all(self):
        # SSH host key
        priv_pem, pub_line, priv_key, pub_key = generate_ssh_ed25519_key(self.hostname)
        (self.keys_dir / "ssh_host_ed25519_key").write_text(priv_pem)
        (self.keys_dir / "ssh_host_ed25519_key.pub").write_text(pub_line + "\n")
        self._ssh_public_key = pub_key

        # Age workstation key
        age_file, age_pub, _ = generate_age_key()
        (self.keys_dir / "age_key.txt").write_text(age_file)
        self.user_age_pubkey = age_pub

        # Convert SSH to age
        self.host_age_pubkey = ed25519_to_x25519_pub(pub_key)
        (self.keys_dir / "host_age_public.txt").write_text(
            "# Host age public key (derived from SSH host key)\n"
            "# This is automatically used by SOPS via the SSH key\n"
            f"{self.host_age_pubkey}\n"
        )


# === Nix Templates ===

def flake_nix(c: Config) -> str:
    return f'''{{
  description = "Declarative NixOS home server flake";

  inputs = {{
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {{
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    }};
    sops-nix = {{
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    }};
  }};

  outputs = {{ self, nixpkgs, disko, sops-nix, ... }}:
    let
      system = "x86_64-linux";
    in {{
      nixosConfigurations.{c.hostname} = nixpkgs.lib.nixosSystem {{
        inherit system;
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hosts/{c.hostname}/configuration.nix
          ./hosts/{c.hostname}/disko.nix
          ./hosts/{c.hostname}/hardware.nix
          ./modules/users.nix
          ./modules/networking.nix
          ./modules/secrets.nix
          ./modules/adguard.nix
          ./modules/caddy.nix
          ./modules/nextcloud.nix
        ];
      }};
    }};
}}
'''


def configuration_nix(c: Config) -> str:
    return f'''{{ config, pkgs, lib, ... }}:

{{
  system.stateVersion = "24.11";

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Locale and time
  time.timeZone = "{c.timezone}";
  i18n.defaultLocale = "{c.locale}";
  console.keyMap = "{c.keymap}";

  # Hostname is set in networking module

  # Minimal package set on the host. Service packages live in their modules.
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    tmux
    curl
    wget
    dig
    pciutils
    usbutils

    # Hashing and security
    age
    sops
    ssh-to-age
  ];

  # Nix settings
  nix.settings = {{
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
  }};
  nix.gc = {{
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  }};

  # SSH
  services.openssh = {{
    enable = true;

    ports = [ {c.ssh_port} ]; # non-standard port

    settings = {{
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    }};
    openFirewall = true;
  }};

  # Fail2ban for SSH brute-force resistance
  services.fail2ban = {{
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment = {{
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h";
    }};
  }};

  # Journald limits so logs do not eat the disk
  services.journald.extraConfig = \'\'
    SystemMaxUse=500M
    MaxRetentionSec=2week
  \'\';
}}
'''


def hardware_nix() -> str:
    return '''{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # CPU microcode. Switch to amd-ucode if running AMD.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # After first nixos-anywhere deploy, regenerate this with:
  #   nixos-generate-config --show-hardware-config --root /mnt
  # and replace this file with the output for an exact hardware match.
}
'''


def disko_nix() -> str:
    return '''{ lib, ... }:

{
  disko.devices = {
    disk = {
      # NVMe for OS
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "noatime" ];
              };
            };
          };
        };
      };
    };
  };

  # SATA HDD for data storage (manually partitioned)
  fileSystems."/srv/data" = {
    device = "/dev/sda1";
    fsType = "ext4";
    options = [ "noatime" ];
  };
}
'''


def users_nix(c: Config) -> str:
    return f'''{{ config, pkgs, ... }}:

{{
  users.mutableUsers = false;

  users.users.{c.admin_username} = {{
    isNormalUser = true;
    description = "Home server administrator";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.bash;
    # Password hash from sops - generate with: mkpasswd -m sha-512
    hashedPasswordFile = config.sops.secrets."admin/password_hash".path;
    openssh.authorizedKeys.keys = [
      "{c.admin_ssh_pubkey}"
    ];
  }};

  # Root has no password and no SSH access. Use sudo from admin for root access
  users.users.root.hashedPassword = "!";

  security.sudo.wheelNeedsPassword = true;
}}
'''


def networking_nix(c: Config) -> str:
    return f'''{{ config, lib, pkgs, ... }}:

{{
  networking = {{
    hostName = "{c.hostname}";
    domain = "{c.domain}";

    # NetworkManager off; we want a deterministic static config.
    networkmanager.enable = false;
    useDHCP = false;

    interfaces.{c.network_interface} = {{
      ipv4.addresses = [{{
        address = "{c.static_ip}";
        prefixLength = {c.prefix_length};
      }}];
    }};

    defaultGateway = "{c.gateway}";

    # Resolve via the locally-running AdGuard Home on 127.0.0.1.
    # Bootstrap nameservers used during early boot before AdGuard is up.
    nameservers = [ "127.0.0.1" "1.1.1.1" "9.9.9.9" ];

    # Static DNS entries so services on the host can resolve internal names
    # without depending on AdGuard rewrites being healthy.
    hosts = {{
      "127.0.0.1" = [ "{c.dns_domain}" "{c.nas_domain}" ];
    }};

    firewall = {{
      enable = true;
      allowPing = true;

      # Deny by default
      allowedTCPPorts = [
        {c.ssh_port}  # SSH
        53    # AdGuard DNS
        443   # Caddy HTTPS
        3000  # AdGuard admin UI
      ];
      allowedUDPPorts = [
        53  # AdGuard DNS
      ];

      # Drop everything else, log it.
      logRefusedConnections = true;
    }};
  }};

  # Disable systemd-resolved; AdGuard binds 127.0.0.1:53.
  services.resolved.enable = false;
}}
'''


def secrets_nix() -> str:
    return '''{ config, ... }:

{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    # Decrypt using the host's SSH key converted to age format.
    # The SSH host key must be added to .sops.yaml before deploy.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "admin/password_hash" = {
        neededForUsers = true;
      };
      "nextcloud/admin_password" = {
        owner = "nextcloud";
        group = "nextcloud";
      };
    };
  };
}
'''


def adguard_nix(c: Config) -> str:
    return f'''{{ config, lib, pkgs, ... }}:

let
  # Used to trigger a restart when settings change
  settingsFormat = pkgs.formats.yaml {{ }};
  configFile = settingsFormat.generate "AdGuardHome.yaml" config.services.adguardhome.settings;
in
{{
  services.adguardhome = {{
    enable = true;
    openFirewall = false;  # Firewall handled centrally in networking.nix
    mutableSettings = false;
    host = "0.0.0.0";
    port = 3000;

    settings = {{
      dns = {{
        # Bind to specific interfaces to avoid conflict with Podman's aardvark-dns on 10.89.0.1
        bind_hosts = [ "127.0.0.1" "{c.static_ip}" ];
        port = 53;

        # Lower rate limiting for home network (default is 20 req/s per client)
        ratelimit = 10;

        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.quad9.net/dns-query"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          "9.9.9.9"
        ];

        # Privacy defaults
        anonymize_client_ip = true;
        statistics_interval = 1;  # 1 day rolling stats only
        querylog_enabled = false;
        querylog_file_enabled = false;

        # Don't use /etc/hosts - manage internal names via rewrites.
        hostsfile_enabled = false;

        # Block reverse lookup leaks for RFC1918 ranges.
        bogus_nxdomain = [ ];
      }};

      filtering = {{
        # Internal name rewrites so .home hostnames resolve to the server.
        rewrites = [
          {{ domain = "{c.dns_domain}"; answer = "{c.static_ip}"; enabled = true; }}
          {{ domain = "{c.nas_domain}"; answer = "{c.static_ip}"; enabled = true; }}
        ];
        protection_enabled = true;
        filtering_enabled = true;
        parental_enabled = false;
        safesearch_enabled = false;
      }};

      filters = [
        {{
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard DNS filter";
          id = 1;
        }}
        {{
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
          name = "AdAway Default Blocklist";
          id = 2;
        }}
      ];

      user_rules = [ ];
    }};
  }};

  # Restart AdGuard when settings change
  systemd.services.adguardhome.restartTriggers = [ configFile ];
}}
'''


def caddy_nix(c: Config) -> str:
    return f'''{{ config, lib, pkgs, ... }}:

{{
  services.caddy = {{
    enable = true;

    virtualHosts = {{
      # Internal domains (local network only, self-signed certs)

      "{c.dns_domain}" = {{
        extraConfig = \'\'
          tls internal
          reverse_proxy localhost:3000
        \'\';
      }};

      # Nextcloud authentication handled by Nextcloud itself
      "{c.nas_domain}" = {{
        extraConfig = \'\'
          tls internal
          reverse_proxy localhost:8080
        \'\';
      }};
    }};
  }};
}}
'''


def nextcloud_nix(c: Config) -> str:
    return f'''{{ config, lib, pkgs, ... }}:

{{
  services.nextcloud = {{
    enable = true;
    package = pkgs.nextcloud33;
    hostName = "{c.nas_domain}";
    https = true;
    datadir = "/srv/data/nextcloud";

    settings = {{
      trusted_proxies = [ "127.0.0.1" ];
      trusted_domains = [ "{c.nas_domain}" ];
      overwriteprotocol = "https";
      default_phone_region = "{c.phone_region}";
      maintenance_window_start = 1;
    }};

    config = {{
      adminuser = "{c.admin_username}";
      adminpassFile = config.sops.secrets."nextcloud/admin_password".path;

      dbtype = "pgsql";
      dbname = "nextcloud";
      dbuser = "nextcloud";
      dbhost = "/run/postgresql";
    }};

    database.createLocally = true;

    configureRedis = true;
    caching.redis = true;

    phpOptions = {{
      "opcache.interned_strings_buffer" = "16";
      "opcache.memory_consumption" = "256";
    }};

    maxUploadSize = "16G";
  }};

  # Make Nextcloud listen on 8080 for Caddy to proxy
  services.nginx.virtualHosts."{c.nas_domain}" = {{
    listen = [{{
      addr = "127.0.0.1";
      port = 8080;
    }}];
  }};

  services.postgresql = {{
    enable = true;
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [{{
      name = "nextcloud";
      ensureDBOwnership = true;
    }}];
  }};

  systemd.services."nextcloud-setup" = {{
    requires = [ "postgresql.service" "srv-data.mount" ];
    after = [ "postgresql.service" "srv-data.mount" ];
  }};
}}
'''


def auto_upgrade_nix(c: Config) -> str:
    url = c.flake_url if c.flake_url else f"github:user/repo#{c.hostname}"
    return f'''{{ config, ... }}:

{{
  system.autoUpgrade = {{
    enable = true;
    flake = "{url}";
    flags = [
      "--update-input" "nixpkgs"
      "--no-write-lock-file"
    ];
    dates = "04:00";
    randomizedDelaySec = "45min";
    allowReboot = true;
  }};

  # Keep three previous generations available for rollback from the bootloader.
  boot.loader.systemd-boot.configurationLimit = 10;
}}
'''


def sops_yaml(c: Config, user_age_pub: str, host_age_pub: str) -> str:
    return f'''keys:
  # Your workstation age key - generate with: age-keygen -o ~/.config/sops/age/keys.txt
  - &user_key {user_age_pub}
  # Server's SSH host key ({c.hostname}) - derived via ssh-to-age
  - &host_{c.hostname} {host_age_pub}

creation_rules:
  - path_regex: secrets/secrets\\.yaml$
    key_groups:
      - age:
          - *user_key
          - *host_{c.hostname}
'''


# === Main Generation ===

def generate(config: Config, output_dir: Path):
    output_dir = Path(output_dir)
    hosts_dir = output_dir / "hosts" / config.hostname
    modules_dir = output_dir / "modules"
    secrets_dir = output_dir / "secrets"

    hosts_dir.mkdir(parents=True, exist_ok=True)
    modules_dir.mkdir(parents=True, exist_ok=True)
    secrets_dir.mkdir(parents=True, exist_ok=True)

    print("Generating cryptographic keys...")
    keygen = KeyGenerator(output_dir, config.hostname)
    keygen.generate_all()

    print("Writing configuration files...")
    (output_dir / "flake.nix").write_text(flake_nix(config))
    (output_dir / ".sops.yaml").write_text(
        sops_yaml(config, keygen.user_age_pubkey, keygen.host_age_pubkey)
    )
    (hosts_dir / "configuration.nix").write_text(configuration_nix(config))
    (hosts_dir / "hardware.nix").write_text(hardware_nix())
    (hosts_dir / "disko.nix").write_text(disko_nix())
    (modules_dir / "users.nix").write_text(users_nix(config))
    (modules_dir / "networking.nix").write_text(networking_nix(config))
    (modules_dir / "secrets.nix").write_text(secrets_nix())
    (modules_dir / "adguard.nix").write_text(adguard_nix(config))
    (modules_dir / "caddy.nix").write_text(caddy_nix(config))
    (modules_dir / "nextcloud.nix").write_text(nextcloud_nix(config))
    (modules_dir / "auto-upgrade.nix").write_text(auto_upgrade_nix(config))

    print("Generating secrets (unencrypted)...")
    password_hash = sha512_crypt(config.admin_password)
    secrets_content = generate_plaintext_secrets(password_hash, config.nextcloud_password)
    (secrets_dir / "secrets.yaml").write_text(secrets_content)

    print(f"\nConfiguration generated in: {output_dir}")
    print(f"\nIMPORTANT - You must encrypt secrets.yaml with sops:")
    print(f"  1. Copy keys/age_key.txt to ~/.config/sops/age/keys.txt")
    print(f"  2. Run: cd {output_dir} && sops -e -i secrets/secrets.yaml")
    print(f"\nKeep the keys/ directory secure and never commit unencrypted secrets!")


def prompt(label: str, default: str = "") -> str:
    if default:
        result = input(f"{label} [{default}]: ").strip()
        return result if result else default
    while True:
        result = input(f"{label}: ").strip()
        if result:
            return result
        print("  (required)")


def prompt_int(label: str, default: int) -> int:
    while True:
        result = input(f"{label} [{default}]: ").strip()
        if not result:
            return default
        try:
            return int(result)
        except ValueError:
            print("  (must be a number)")


def prompt_password(label: str) -> str:
    import getpass
    while True:
        p1 = getpass.getpass(f"{label}: ")
        p2 = getpass.getpass(f"Confirm {label}: ")
        if p1 == p2:
            if p1:
                return p1
            print("  (required)")
        else:
            print("  (passwords don't match)")


def main():
    print("=" * 60)
    print("  NixOS Home Server Configuration Generator")
    print("=" * 60)
    print()

    config = Config()

    print("-- Network Settings --")
    config.hostname = prompt("Hostname", config.hostname)
    config.domain = prompt("Domain", config.domain)
    config.network_interface = prompt("Network interface", config.network_interface)
    config.static_ip = prompt("Static IP", config.static_ip)
    config.prefix_length = prompt_int("Prefix length", config.prefix_length)
    config.gateway = prompt("Gateway", config.gateway)
    config.ssh_port = prompt_int("SSH port", config.ssh_port)

    print("\n-- User Settings --")
    config.admin_username = prompt("Admin username", config.admin_username)
    config.admin_password = prompt_password("Admin password")
    config.admin_ssh_pubkey = prompt("Admin SSH public key")
    config.nextcloud_password = prompt_password("Nextcloud admin password")

    print("\n-- System Settings --")
    config.timezone = prompt("Timezone", config.timezone)
    config.locale = prompt("Locale", config.locale)
    config.keymap = prompt("Console keymap", config.keymap)
    config.phone_region = prompt("Phone region (ISO 3166-1)", config.phone_region)
    config.flake_url = input(f"GitHub flake URL (optional): ").strip()

    print("\n-- Output --")
    output_dir = prompt("Output directory", "./output")

    print()
    generate(config, Path(output_dir))


if __name__ == "__main__":
    main()
