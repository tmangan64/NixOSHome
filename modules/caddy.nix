{ config, lib, pkgs, ... }:

{
  services.caddy = {
    enable = true;

    virtualHosts = {
      # Internal domains (local network only, self-signed certs)

      "dns.home" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:3000
        '';
      };

      # Nextcloud authentication handled by Nextcloud itself
      "nas.home" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8080
        '';
      };
    };
  };
}
