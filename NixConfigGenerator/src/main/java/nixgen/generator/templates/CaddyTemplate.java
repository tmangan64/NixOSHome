package nixgen.generator.templates;

import nixgen.model.ConfigData;

public class CaddyTemplate {
    public static String generate(ConfigData config) {
        return String.format("""
{ config, lib, pkgs, ... }:

{
  services.caddy = {
    enable = true;

    virtualHosts = {
      # Internal domains (local network only, self-signed certs)

      "%s" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:3000
        '';
      };

      # Nextcloud authentication handled by Nextcloud itself
      "%s" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8080
        '';
      };
    };
  };
}
""", config.getDnsDomain(), config.getNasDomain());
    }
}
