{ config, pkgs, lib, opts, ... }:

{
  system.stateVersion = "24.11";

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Locale and time
  time.timeZone = opts.timeZone;
  i18n.defaultLocale = opts.locale;
  console.keyMap = opts.keyMap;

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
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # SSH
  services.openssh = {
    enable = true;

    ports = [ opts.sshPort ];

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    openFirewall = true;
  };

  # Fail2ban for SSH brute-force resistance
  services.fail2ban = {
    enable = true;
    maxretry = opts.fail2banMaxRetry;
    bantime = opts.fail2banBantime;
    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h";
    };
  };

  # Journald limits so logs do not eat the disk
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=2week
  '';
}
