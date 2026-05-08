{ config, opts, ... }:

{
  sops = {
    defaultSopsFile = ../options/secrets.yaml;
    defaultSopsFormat = "yaml";

    # Decrypt using the host's SSH key converted to age format.
    # The SSH host key must be added to .sops.yaml before deploy.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "${opts.adminUser}/password_hash" = {
        neededForUsers = true;
      };
      "nextcloud/admin_password" = {
        owner = "nextcloud";
        group = "nextcloud";
      };
    };
  };
}
