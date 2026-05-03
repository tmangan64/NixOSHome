package nixgen.generator.templates;

import nixgen.model.ConfigData;

public class FlakeTemplate {
    public static String generate(ConfigData config) {
        return String.format("""
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
    in {
      nixosConfigurations.%s = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hosts/%s/configuration.nix
          ./hosts/%s/disko.nix
          ./hosts/%s/hardware.nix
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
""", config.getHostname(), config.getHostname(), config.getHostname(), config.getHostname());
    }
}
