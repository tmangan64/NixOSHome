{ config, lib, pkgs, opts, ... }:

{
  services.caddy = {
    enable = true;

    virtualHosts = {
      # Internal domains (local network only, self-signed certs)

      ${opts.dnsDomain} = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:${toString opts.adguardPort}
        '';
      };

      # Nextcloud authentication handled by Nextcloud itself
      ${opts.nextcloudDomain} = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:${toString opts.nextcloudPort}
        '';
      };
    };
  };
}
