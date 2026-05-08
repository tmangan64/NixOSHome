{ config, pkgs, opts, ... }:

{
  users.mutableUsers = false;

  users.users.${opts.adminUser} = {
    isNormalUser = true;
    description = "Home server administrator";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.bash;
    # Password hash from sops - generate with: mkpasswd -m sha-512
    hashedPasswordFile = config.sops.secrets."${opts.adminUser}/password_hash".path;
    openssh.authorizedKeys.keys = opts.sshKeys;
  };

  # Root has no password and no SSH access. Use sudo from admin for root access
  users.users.root.hashedPassword = "!";

  # Passwordless sudo for wheel group - SSH key authentication provides security
  security.sudo.wheelNeedsPassword = false;
}
