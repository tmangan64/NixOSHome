package nixgen.generator.templates;

import nixgen.model.ConfigData;

public class AutoUpgradeTemplate {
    public static String generate(ConfigData config) {
        String flakeUrl = config.getGithubFlakeUrl();
        if (flakeUrl == null || flakeUrl.isEmpty()) {
            flakeUrl = "github:user/repo#" + config.getHostname();
        }

        return String.format("""
{ config, ... }:

{
  system.autoUpgrade = {
    enable = true;
    flake = "%s";
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
""", flakeUrl);
    }
}
