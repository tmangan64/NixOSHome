{ config, lib, pkgs, userConfig, ... }:

{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud30;
    hostName = "cloud.${userConfig.domain}";
    https = true;  # we are reverse proxied behind Caddy with TLS

    # Listen only on loopback. Caddy proxies to it.
    settings = {
      trusted_proxies = [ "127.0.0.1" ];
      trusted_domains = [ "cloud.${userConfig.domain}" ];
      overwriteprotocol = "https";
      default_phone_region = userConfig.phoneRegion;
      maintenance_window_start = 1;
    };

    config = {
      adminuser = userConfig.username;
      adminpassFile = config.sops.secrets."nextcloud/admin_password".path;

      dbtype = "pgsql";
      dbname = "nextcloud";
      dbuser = "nextcloud";
      dbhost = "/run/postgresql";
    };

    database.createLocally = true;

    configureRedis = true;
    caching.redis = true;

    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
      "opcache.memory_consumption" = "256";
      "memory_limit" = "512M";
    };

    maxUploadSize = "16G";
  };

  # Make Nextcloud listen on 8080 for Caddy to proxy.
  services.nginx.virtualHosts."cloud.${userConfig.domain}" = {
    listen = [{
      addr = "127.0.0.1";
      port = 8080;
    }];
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [{
      name = "nextcloud";
      ensureDBOwnership = true;
    }];
  };

  systemd.services."nextcloud-setup" = {
    requires = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
  };

  # Add Nextcloud secret to sops
  sops.secrets."nextcloud/admin_password" = { };
}
