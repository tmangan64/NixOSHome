{ config, pkgs, ... }:

{
  users.mutableUsers = false;

  users.users.admin = {
    isNormalUser = true;
    description = "Home server administrator";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.bash;
    # Password hash from sops - generate with: mkpasswd -m sha-512
    hashedPasswordFile = config.sops.secrets."admin/password_hash".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPHEr9l0xPvco+x1zz2X5skaIwpjtI0+QGOELm/KtV5d kiroshi"
    ];
  };

  # Root has no password and no SSH access. Use sudo from admin for root access
  users.users.root.hashedPassword = "!";

  security.sudo.wheelNeedsPassword = true;
}
