{ config, pkgs, userConfig, ... }:

{
  users.mutableUsers = false;

  users.users.admin = {
    isNormalUser = true;
    description = "Home server administrator";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.bash;
    hashedPasswordFile = config.sops.secrets."admin/password_hash".path;
    openssh.authorizedKeys.keys = [
      userConfig.ssh.publicKey
    ];
  };

  users.users.root.hashedPassword = "!";

  security.sudo.wheelNeedsPassword = true;
}
