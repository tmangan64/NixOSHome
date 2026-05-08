# NixOS Options Generator

A graphical tool for generating NixOS configuration files.

## Running

```bash
nix-shell --run "python nixgen.py"
```

## What It Generates

Creates two files in the `options/` directory:

1. **options.nix** - All configuration values
2. **secrets.yaml** - Passwords (must be encrypted before committing)

## After Generating

See the main [README.md](../README.md) for next steps.
