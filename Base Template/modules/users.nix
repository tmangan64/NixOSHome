{ config, pkgs, userConfig, ... }:

{
  users.mutableUsers = false;

  users.users.${userConfig.username} = {
    isNormalUser = true;
    description = userConfig.userDescription;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.bash;
    # Password hash from sops. Generate with: mkpasswd -m sha-512
    hashedPasswordFile = config.sops.secrets."${userConfig.username}/password_hash".path;
    openssh.authorizedKeys.keys = [
      userConfig.sshPublicKey
    ];
  };

  # Root has no password and no SSH access. Use sudo from admin.
  users.users.root.hashedPassword = "!";

  security.sudo.wheelNeedsPassword = true;
}
