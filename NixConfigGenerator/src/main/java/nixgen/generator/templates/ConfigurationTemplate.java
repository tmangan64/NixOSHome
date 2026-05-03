package nixgen.generator.templates;

import nixgen.model.ConfigData;

public class ConfigurationTemplate {
    public static String generate(ConfigData config) {
        return String.format("""
{ config, pkgs, lib, ... }:

{
  system.stateVersion = "24.11";

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Locale and time
  time.timeZone = "%s";
  i18n.defaultLocale = "%s";
  console.keyMap = "%s";

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

    ports = [ %d ]; # non-standard port

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
    maxretry = 5;
    bantime = "1h";
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
""", config.getTimezone(), config.getLocale(), config.getConsoleKeymap(), config.getSshPort());
    }
}
