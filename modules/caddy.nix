{ config, lib, pkgs, ... }:

let
  duckdnsSubdomain = "barnsfold";
in {
  services.caddy = {
    enable = true;

    globalConfig = ''
      auto_https disable_redirects
    '';

    virtualHosts = {
      # =========================================================================
      # INTERNAL DOMAINS (local network only, self-signed certs)
      # =========================================================================

      "dns.home" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:3000
        '';
      };

      # Nextcloud - direct access (authentication handled by Nextcloud itself)
      "nas.home" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8080
        '';
      };

      # =========================================================================
      # EXTERNAL DOMAINS (internet-accessible, Let's Encrypt certs)
      # =========================================================================

      # Nextcloud - external access
      "cloud.${duckdnsSubdomain}.duckdns.org" = {
        extraConfig = ''
          reverse_proxy localhost:8080
        '';
      };
    };
  };

  # Open port 80 for Let's Encrypt HTTP-01 challenge
  networking.firewall.allowedTCPPorts = [ 80 ];
}
