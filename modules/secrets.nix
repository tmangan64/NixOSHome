{ config, self, ... }: # Add 'self' to the arguments

{
  sops = {
    # This ensures Nix looks at the 'secrets' folder in the root of your flake
    defaultSopsFile = "${self}/secrets/secrets.yaml"; 
    defaultSopsFormat = "yaml";
    
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.generateKey = true;

    secrets = {
      "admin/password_hash" = {
        neededForUsers = true;
      };
    };
  };
}