# NixOS Options Generator

A graphical tool for generating NixOS configuration files.

## Running

```bash
nix-shell --run "python nixgen.py"
```

## What It Generates

Creates three files in the `options/` directory:

1. **options.nix** - All configuration values
2. **secrets.yaml** - Passwords (must be encrypted before committing)
3. **.sops.yaml** - SOPS encryption configuration

## After Generating

Encrypt your secrets:

```bash
cd options
nix-shell -p sops --run "sops --encrypt --in-place secrets.yaml"
```

See the main [README.md](../README.md) for deployment steps.
