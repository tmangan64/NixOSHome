{ config, lib, pkgs, ... }:

let
  # Change this to your DuckDNS subdomain (e.g., "myserver" for myserver.duckdns.org)
  # DuckDNS automatically resolves subdomains: auth.myserver.duckdns.org → same IP
  duckdnsSubdomain = "barnsfold";
in {
  services.caddy = {
    enable = true;

    # Mixed mode: internal certs for .home, ACME for external domains
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

      "nas.home" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8080
        '';
      };

      "auth.home" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:9000
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

      # Authentik - external access (required for SSO redirects)
      "auth.${duckdnsSubdomain}.duckdns.org" = {
        extraConfig = ''
          reverse_proxy localhost:9000
        '';
      };
    };
  };

  # Open port 80 for Let's Encrypt HTTP-01 challenge
  networking.firewall.allowedTCPPorts = [ 80 ];
}
