{ config, lib, pkgs, ... }:

# Authentik is not packaged as a NixOS service in nixpkgs.
# We deploy it declaratively via OCI containers (Podman backend).
# The whole compose-equivalent state is expressed here; no docker-compose file needed.

let
  authentikVersion = "2025.10.0";
  postgresVersion = "16-alpine";
  redisVersion = "alpine";

  # Declarative blueprints for Authentik configuration
  blueprintsDir = pkgs.runCommand "authentik-blueprints" {} ''
    mkdir -p $out
    cp -r ${../authentik-blueprints}/* $out/
  '';
in {
  virtualisation = {
    podman = {
      enable = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    oci-containers.backend = "podman";
  };

  # Persistent volumes for the stack.
  # Authentik server/worker run as UID 1000, postgres as UID 70, redis as UID 999
  systemd.tmpfiles.rules = [
    "d /var/lib/authentik 0750 root root - -"
    "d /var/lib/authentik/media 0750 1000 1000 - -"
    "d /var/lib/authentik/templates 0750 1000 1000 - -"
    "d /var/lib/authentik/certs 0750 1000 1000 - -"
    "d /var/lib/authentik/postgres 0700 70 70 - -"
    "d /var/lib/authentik/redis 0750 999 999 - -"
  ];

  virtualisation.oci-containers.containers = {
    authentik-postgres = {
      image = "docker.io/library/postgres:${postgresVersion}";
      autoStart = true;
      environment = {
        POSTGRES_USER = "authentik";
        POSTGRES_DB = "authentik";
      };
      environmentFiles = [
        # File contents must be: POSTGRES_PASSWORD=<value>
        # We render it from sops at activation time below.
        "/run/authentik/postgres.env"
      ];
      volumes = [
        "/var/lib/authentik/postgres:/var/lib/postgresql/data"
      ];
      extraOptions = [ "--network=authentik" ];
    };

    authentik-redis = {
      image = "docker.io/library/redis:${redisVersion}";
      autoStart = true;
      cmd = [ "--save" "60" "1" "--loglevel" "warning" ];
      volumes = [
        "/var/lib/authentik/redis:/data"
      ];
      extraOptions = [ "--network=authentik" ];
    };

    authentik-server = {
      image = "ghcr.io/goauthentik/server:${authentikVersion}";
      autoStart = true;
      cmd = [ "server" ];
      ports = [ "127.0.0.1:9000:9000" ];
      environment = {
        AUTHENTIK_REDIS__HOST = "authentik-redis";
        AUTHENTIK_POSTGRESQL__HOST = "authentik-postgres";
        AUTHENTIK_POSTGRESQL__USER = "authentik";
        AUTHENTIK_POSTGRESQL__NAME = "authentik";
      };
      environmentFiles = [
        "/run/authentik/server.env"
      ];
      volumes = [
        "/var/lib/authentik/media:/media"
        "/var/lib/authentik/templates:/templates"
        "${blueprintsDir}:/blueprints/custom:ro"
      ];
      dependsOn = [ "authentik-postgres" "authentik-redis" ];
      extraOptions = [ "--network=authentik" ];
    };

    authentik-worker = {
      image = "ghcr.io/goauthentik/server:${authentikVersion}";
      autoStart = true;
      cmd = [ "worker" ];
      environment = {
        AUTHENTIK_REDIS__HOST = "authentik-redis";
        AUTHENTIK_POSTGRESQL__HOST = "authentik-postgres";
        AUTHENTIK_POSTGRESQL__USER = "authentik";
        AUTHENTIK_POSTGRESQL__NAME = "authentik";
      };
      environmentFiles = [
        "/run/authentik/server.env"
      ];
      volumes = [
        "/var/lib/authentik/media:/media"
        "/var/lib/authentik/templates:/templates"
        "/var/lib/authentik/certs:/certs"
        "${blueprintsDir}:/blueprints/custom:ro"
      ];
      dependsOn = [ "authentik-postgres" "authentik-redis" ];
      extraOptions = [ "--network=authentik" ];
    };
  };

  # Create the podman network before containers start.
  systemd.services.authentik-network = {
    description = "Create Authentik podman network";
    wantedBy = [ "multi-user.target" ];
    before = [
      "podman-authentik-postgres.service"
      "podman-authentik-redis.service"
      "podman-authentik-server.service"
      "podman-authentik-worker.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.podman}/bin/podman network create --ignore authentik";
      ExecStop = "${pkgs.podman}/bin/podman network rm -f authentik";
    };
  };

  # Render env files from sops secrets at boot.
  systemd.services.authentik-render-env = {
    description = "Render Authentik environment files from sops secrets";
    wantedBy = [ "multi-user.target" ];
    before = [
      "podman-authentik-postgres.service"
      "podman-authentik-server.service"
      "podman-authentik-worker.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /run/authentik
      chmod 0750 /run/authentik

      DB_PASS=$(cat ${config.sops.secrets."authentik/db_password".path})
      SECRET_KEY=$(cat ${config.sops.secrets."authentik/secret_key".path})

      umask 077
      cat > /run/authentik/postgres.env <<EOF
POSTGRES_PASSWORD=$DB_PASS
EOF

      cat > /run/authentik/server.env <<EOF
AUTHENTIK_SECRET_KEY=$SECRET_KEY
AUTHENTIK_POSTGRESQL__PASSWORD=$DB_PASS
EOF
    '';
  };
}
