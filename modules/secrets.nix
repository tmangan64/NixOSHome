{ config, ... }:

{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    # Decrypt using the host's SSH key converted to age format.
    # The SSH host key must be added to .sops.yaml before deploy.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "admin/password_hash" = {
        neededForUsers = true;
      };
      "nextcloud/admin_password" = {
        owner = "nextcloud";
        group = "nextcloud";
      };
      "authentik/db_password" = {};
      "authentik/secret_key" = {};
      "wireguard/private_key" = {};
      "duckdns/token" = {
        mode = "0444";  # World-readable since it's only used for IP updates
      };
    };
  };
}