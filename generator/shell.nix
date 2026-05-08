{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    python3Packages.tkinter
  ];

  shellHook = ''
    echo "NixOS Options Generator Development Environment"
    echo "Run: python nixgen.py"
  '';
}
