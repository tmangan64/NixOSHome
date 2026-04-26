{ config, lib, pkgs, ... }:

{
  services.caddy = {
    enable = true;

    # Internal CA mode: Caddy generates its own root and issues certs from it.
    # First-time browser visits will warn until the root cert (printed in caddy
    # logs at first start, or fetched from /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt)
    # is installed on each client.
    globalConfig = ''
      auto_https disable_redirects
      local_certs
    '';

    virtualHosts = {
      "dns.home" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:3000
        '';
      };
    };
  };
}
