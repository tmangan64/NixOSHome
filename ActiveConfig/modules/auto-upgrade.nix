{ config, ... }:

{
  system.autoUpgrade = {
    enable = true;
    flake = "github:tmangan64/NixOSHome#homeserver";
    flags = [
      "--update-input" "nixpkgs"
      "--no-write-lock-file"
    ];
    dates = "04:00";
    randomizedDelaySec = "45min";
    allowReboot = true;
  };

  # Keep three previous generations available for rollback from the bootloader.
  boot.loader.systemd-boot.configurationLimit = 10;
}
