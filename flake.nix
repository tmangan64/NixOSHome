{
  description = "Declarative NixOS home server flake";

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
      system = "x86_64-linux";
      opts = import ./options/options.nix;

      # Override nextcloud33 to version 33.0.3 to prevent downgrade error 7/5/2026
      nextcloudOverlay = final: prev: {
        nextcloud33 = prev.nextcloud33.overrideAttrs (old: rec {
          version = "33.0.3";
          src = prev.fetchurl {
            url = "https://download.nextcloud.com/server/releases/nextcloud-${version}.tar.bz2";
            sha256 = "sha256-XBBS+GCzWqVrJLwmE6a+oMIjE7n70CuwJHwfC52/d9I=";
          };
        });
      };
    in {
      nixosConfigurations.${opts.hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit opts; };
        modules = [
          { nixpkgs.overlays = [ nextcloudOverlay ]; }
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./config/configuration.nix
          ./config/disko.nix
          ./config/hardware.nix
          ./modules/users.nix
          ./modules/networking.nix
          ./modules/secrets.nix
          ./modules/adguard.nix
          ./modules/caddy.nix
          ./modules/nextcloud.nix
          ./modules/auto-upgrade.nix
        ];
      };
    };
}
