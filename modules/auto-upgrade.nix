{ config, userConfig, ... }:

{
  system.autoUpgrade = {
    enable = true;
    flake = "github:${userConfig.github.username}/${userConfig.github.repo}#homeserver";
    flags = [
      "--update-input" "nixpkgs"
      "--no-write-lock-file"
    ];
    dates = "04:00";
    randomizedDelaySec = "45min";
    allowReboot = true;
  };

  boot.loader.systemd-boot.configurationLimit = 10;
}
