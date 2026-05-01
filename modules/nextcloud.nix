{ config, lib, pkgs, ... }:

let
  # Change this to your DuckDNS subdomain (e.g., "myserver" for myserver.duckdns.org)
  duckdnsSubdomain = "barnsfold";
  externalDomain = "cloud.${duckdnsSubdomain}.duckdns.org";
  externalAuthDomain = "auth.${duckdnsSubdomain}.duckdns.org";
in {
  # Enable the user_oidc app for SSO with Authentik
  services.nextcloud.extraApps = {
    user_oidc = pkgs.fetchNextcloudApp {
      appName = "user_oidc";
      sha256 = "sha256-Sc7R/hkjAvRUC4aUOLbMucoNabcXt27XB1pwqlz2Zv0=";
      url = "https://github.com/nextcloud-releases/user_oidc/releases/download/v8.10.1/user_oidc-v8.10.1.tar.gz";
      appVersion = "8.10.1";
      license = "agpl3Plus";
    };
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = "nas.home";
    https = true;  # we are reverse proxied behind Caddy with TLS
    datadir = "/srv/data/nextcloud";

    # Listen only on loopback. Caddy proxies to it.
    settings = {
      trusted_proxies = [ "127.0.0.1" ];
      trusted_domains = [ "nas.home" externalDomain ];
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
      # Use combined CA bundle that includes Caddy's internal CA
      # This allows OIDC connections to auth.home while keeping external CAs
      "curl.cainfo" = "/run/caddy-ca/ca-bundle.crt";
      "openssl.cafile" = "/run/caddy-ca/ca-bundle.crt";
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

  # Configure OIDC providers for Authentik SSO
  # Creates two providers: one for internal access, one for external
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
      SECRET=$(cat ${clientSecret})

      # Internal OIDC provider (for nas.home access)
      if ! nextcloud-occ user_oidc:provider Authentik 2>/dev/null | grep -q "Authentik"; then
        nextcloud-occ user_oidc:provider Authentik \
          --clientid="nextcloud" \
          --clientsecret="$SECRET" \
          --discoveryuri="https://auth.home/application/o/nextcloud/.well-known/openid-configuration" \
          --scope="openid email profile" \
          --unique-uid=1 \
          --check-bearer=1
        echo "Internal OIDC provider configured"
      else
        echo "Internal OIDC provider already exists"
      fi

      # External OIDC provider (for cloud.SUBDOMAIN.duckdns.org access)
      if ! nextcloud-occ user_oidc:provider "Authentik External" 2>/dev/null | grep -q "Authentik External"; then
        nextcloud-occ user_oidc:provider "Authentik External" \
          --clientid="nextcloud" \
          --clientsecret="$SECRET" \
          --discoveryuri="https://${externalAuthDomain}/application/o/nextcloud/.well-known/openid-configuration" \
          --scope="openid email profile" \
          --unique-uid=1 \
          --check-bearer=1
        echo "External OIDC provider configured"
      else
        echo "External OIDC provider already exists"
      fi
    '';
  };
}
