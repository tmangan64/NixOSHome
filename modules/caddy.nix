{ config, lib, pkgs, ... }:

let
  # Change this to your DuckDNS subdomain (e.g., "myserver" for myserver.duckdns.org)
  # DuckDNS automatically resolves subdomains: auth.myserver.duckdns.org → same IP
  duckdnsSubdomain = "barnsfold";

  caddyCAPath = "/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt";
  caBundle = "/var/lib/caddy-ca/ca-bundle.crt";
in {
  # Persistent directory for the CA bundle
  systemd.tmpfiles.rules = [
    "d /var/lib/caddy-ca 0755 root root - -"
  ];

  # Create combined CA bundle after Caddy generates its internal CA
  systemd.services.caddy-ca-bundle = {
    description = "Create CA bundle with Caddy internal CA";
    after = [ "caddy.service" ];
    before = [ "phpfpm-nextcloud.service" ];
    requiredBy = [ "phpfpm-nextcloud.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      # Wait for Caddy to generate its CA (up to 120 seconds)
      echo "Waiting for Caddy CA..."
      for i in $(seq 1 120); do
        if [ -f "${caddyCAPath}" ]; then
          echo "Found Caddy CA, creating bundle..."
          cat /etc/ssl/certs/ca-certificates.crt "${caddyCAPath}" > "${caBundle}"
          chmod 644 "${caBundle}"
          echo "CA bundle created at ${caBundle}"
          exit 0
        fi
        sleep 1
      done
      echo "ERROR: Caddy CA not found after 120 seconds"
      exit 1
    '';
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
