package nixgen.generator.templates;

import nixgen.model.ConfigData;

public class UsersTemplate {
    public static String generate(ConfigData config) {
        return String.format("""
{ config, pkgs, ... }:

{
  users.mutableUsers = false;

  users.users.%s = {
    isNormalUser = true;
    description = "Home server administrator";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.bash;
    # Password hash from sops - generate with: mkpasswd -m sha-512
    hashedPasswordFile = config.sops.secrets."admin/password_hash".path;
    openssh.authorizedKeys.keys = [
      "%s"
    ];
  };

  # Root has no password and no SSH access. Use sudo from admin for root access
  users.users.root.hashedPassword = "!";

  security.sudo.wheelNeedsPassword = true;
}
""", config.getAdminUsername(), config.getAdminSshPublicKey());
    }
}
