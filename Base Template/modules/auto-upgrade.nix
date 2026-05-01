{ config, userConfig, ... }:

{
  system.autoUpgrade = {
    enable = true;
    flake = "github:${userConfig.githubUsername}/${userConfig.githubRepo}#${userConfig.hostname}";
    flags = [
      "--update-input" "nixpkgs"
      "--no-write-lock-file"
      "--commit-lock-file"
    ];
    dates = "04:00";
    randomizedDelaySec = "45min";
    allowReboot = false;
  };

  # Keep previous generations available for rollback from the bootloader.
  boot.loader.systemd-boot.configurationLimit = 10;
}
