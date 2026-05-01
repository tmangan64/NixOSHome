{ config, ... }:

{
  system.autoUpgrade = {
    enable = true;
    flake = "github:YOUR_USERNAME/homeserver-flake#homeserver";
    flags = [
      "--update-input" "nixpkgs"
      "--no-write-lock-file"
      "--commit-lock-file"
    ];
    dates = "04:00";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };

  # Keep three previous generations available for rollback from the bootloader.
  boot.loader.systemd-boot.configurationLimit = 10;
}
