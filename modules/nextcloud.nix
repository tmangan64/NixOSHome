{ config, lib, pkgs, ... }:

{
  # Enable the user_oidc app for SSO with Authentik
  services.nextcloud.extraApps = {
    user_oidc = pkgs.fetchNextcloudApp {
      appName = "user_oidc";
      sha256 = "sha256-SzSLPdxSVFNRwmMJUkF5r2lIphIG3EkaoXIEQqkD2lc=";
      url = "https://github.com/nextcloud-releases/user_oidc/releases/download/v6.1.1/user_oidc-v6.1.1.tar.gz";
      appVersion = "6.1.1";
      license = "agpl3Plus";
    };
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    hostName = "nas.home";
    https = true;  # we are reverse proxied behind Caddy with TLS
    datadir = "/srv/data/nextcloud";

    # Listen only on loopback. Caddy proxies to it.
    settings = {
      trusted_proxies = [ "127.0.0.1" ];
      trusted_domains = [ "nas.home" ];
      overwriteprotocol = "https";
      default_phone_region = "GB";
      maintenance_window_start = 1;
    };

    config = {
      adminuser = "admin";
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

    maxUploadSize = "16G";
  };

  # Make Nextcloud listen on 8080 for Caddy to proxy.
  services.nginx.virtualHosts."nas.home" = {
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
    requires = [ "postgresql.service" "srv-data.mount" ];
    after = [ "postgresql.service" "srv-data.mount" ];
  };

  # Configure OIDC provider for Authentik SSO
  # This runs after nextcloud-setup to register the OIDC provider
  systemd.services."nextcloud-oidc-setup" = {
    description = "Configure Nextcloud OIDC for Authentik";
    after = [ "nextcloud-setup.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.services.nextcloud.occ ];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      RemainAfterExit = true;
    };
    script = let
      clientSecret = config.sops.secrets."authentik/nextcloud_client_secret".path;
    in ''
      # Check if provider already exists
      if ! nextcloud-occ user_oidc:provider Authentik 2>/dev/null | grep -q "Authentik"; then
        # Read the client secret
        SECRET=$(cat ${clientSecret})

        # Create the OIDC provider
        nextcloud-occ user_oidc:provider Authentik \
          --clientid="nextcloud" \
          --clientsecret="$SECRET" \
          --discoveryuri="https://auth.home/application/o/nextcloud/.well-known/openid-configuration" \
          --scope="openid email profile" \
          --unique-uid=1 \
          --check-bearer=1

        echo "OIDC provider configured"
      else
        echo "OIDC provider already exists"
      fi
    '';
  };
}
