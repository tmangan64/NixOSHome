{
  description = "Declarative NixOS home server flake - Base Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, ... }:
    let
      # Import user configuration
      userConfig = import ./user-config.nix;
      system = userConfig.platform;
    in {
      nixosConfigurations.${userConfig.hostname} = nixpkgs.lib.nixosSystem {
        inherit system;

        # Pass userConfig to all modules via specialArgs
        specialArgs = { inherit userConfig; };

        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hosts/homeserver/configuration.nix
          ./hosts/homeserver/disko.nix
          ./hosts/homeserver/hardware.nix
          ./modules/users.nix
          ./modules/networking.nix
          ./modules/secrets.nix
          ./modules/adguard.nix
          ./modules/caddy.nix
          # Uncomment modules as needed:
          # ./modules/nextcloud.nix
          # ./modules/authentik.nix
          # ./modules/wireguard.nix
          # ./modules/auto-upgrade.nix
        ];
      };
    };
}
