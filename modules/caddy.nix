{ config, lib, pkgs, ... }:

let
  # Change this to your DuckDNS subdomain (e.g., "myserver" for myserver.duckdns.org)
  # DuckDNS automatically resolves subdomains: auth.myserver.duckdns.org → same IP
  duckdnsSubdomain = "barnsfold";

  # Caddy's internal CA certificate location
  caddyCAPath = "/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt";
  # Use /run for runtime-generated files (writable in NixOS)
  combinedCABundle = "/run/caddy-ca/ca-bundle.crt";
in {
  # Create a combined CA bundle with system CAs + Caddy's internal CA
  # This allows services like Nextcloud to trust both external and internal HTTPS
  systemd.services.caddy-export-ca = {
    description = "Export Caddy internal CA and create combined bundle";
    after = [ "caddy.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /run/caddy-ca

      # Wait for Caddy to generate its CA (up to 60 seconds)
      for i in $(seq 1 60); do
        if [ -f "${caddyCAPath}" ]; then
          # Create combined bundle: system CAs + Caddy CA
          cat /etc/ssl/certs/ca-certificates.crt "${caddyCAPath}" > ${combinedCABundle}
          chmod 644 ${combinedCABundle}
          echo "Combined CA bundle created at ${combinedCABundle}"
          exit 0
        fi
        sleep 1
      done
      echo "Warning: Caddy CA not found, using system bundle only"
      cp /etc/ssl/certs/ca-certificates.crt ${combinedCABundle}
    '';
  };

  # Ensure PHP-FPM restarts after CA is available (for Nextcloud OIDC)
  systemd.services.phpfpm-nextcloud = {
    after = [ "caddy-export-ca.service" ];
    wants = [ "caddy-export-ca.service" ];
  };

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
