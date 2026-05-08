{ config, lib, pkgs, opts, ... }:

{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = opts.nextcloudDomain;
    https = true;
    datadir = opts.nextcloudDataDir;

    settings = {
      trusted_proxies = [ "127.0.0.1" ];
      trusted_domains = [ opts.nextcloudDomain ];
      overwriteprotocol = "https";
      default_phone_region = opts.phoneRegion;
      maintenance_window_start = 1;
    };

    config = {
      adminuser = opts.adminUser;
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
    };

    maxUploadSize = opts.nextcloudMaxUpload;
  };

  # Make Nextcloud listen on internal port for Caddy to proxy
  services.nginx.virtualHosts.${opts.nextcloudDomain} = {
    listen = [{
      addr = "127.0.0.1";
      port = opts.nextcloudPort;
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
    requires = [ "postgresql.service" "srv-data.mount" ];
    after = [ "postgresql.service" "srv-data.mount" ];
  };
}
