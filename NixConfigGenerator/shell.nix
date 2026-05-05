{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python312
    python312Packages.cryptography
  ];

  shellHook = ''
    echo "NixOS Config Generator"
    echo "Run: python nixgen.py"
  '';
}
