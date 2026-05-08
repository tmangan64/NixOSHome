# Secrets Setup Guide

This guide explains how to manage secrets using SOPS and age encryption.

## Overview

This configuration uses:
- **SOPS** - Secrets OPerationS, a tool for encrypting secrets in files
- **age** - A modern encryption tool (simpler than GPG)
- **sops-nix** - NixOS integration for SOPS

Secrets are encrypted in the repository and decrypted at runtime on the server.

## How It Works

1. Secrets are stored in `flake/options/secrets.yaml`
2. The file is encrypted with age keys
3. Both your workstation key and the server's key can decrypt
4. sops-nix decrypts secrets during NixOS activation
5. Services access secrets via file paths

## Setting Up Your Workstation

### Install Required Tools

```bash
# Using nix-shell
nix-shell -p age sops ssh-to-age

# Or add to your NixOS/home-manager config
environment.systemPackages = [ age sops ssh-to-age ];
```

### Generate Your Age Key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

This creates a key pair. The output shows your public key:

```
# created: 2024-01-01T12:00:00Z
# public key: age1abc123xyz...
AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**Keep the secret key safe!** Anyone with this key can decrypt your secrets.

### Find Your Public Key

```bash
grep "public key" ~/.config/sops/age/keys.txt
```

Or extract from the key file:

```bash
age-keygen -y ~/.config/sops/age/keys.txt
```

## Setting Up the Server Key

The server uses its SSH host key for decryption. This key is generated during NixOS installation.

### Get the Host Key After Deploy

SSH to the server and get the key:

```bash
ssh -p SSH_PORT admin@SERVER_IP \
  "sudo cat /etc/ssh/ssh_host_ed25519_key.pub" | ssh-to-age
```

Or scan from your workstation:

```bash
ssh-keyscan -p SSH_PORT SERVER_IP 2>/dev/null | ssh-to-age
```

### Before First Deploy (Bootstrapping)

For the initial deploy, you have two options:

1. **Use only your workstation key** - The first rebuild will fail to decrypt, then add the host key and re-encrypt

2. **Pre-generate the host key** - Generate a host key, deploy it, and encrypt secrets with both keys from the start

Option 1 is simpler and recommended.

## Configuring SOPS

### Create .sops.yaml

The `.sops.yaml` file tells SOPS which keys to use:

```yaml
keys:
  # Your workstation key
  - &user_key age1abc123...your.workstation.public.key...

  # Server's SSH host key (converted to age)
  - &host_homeserver age1xyz789...server.host.public.key...

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *user_key
          - *host_homeserver
```

Place this file at `flake/options/.sops.yaml`.

### Multiple Servers

For multiple servers, add each host key:

```yaml
keys:
  - &user_key age1abc...
  - &host_server1 age1def...
  - &host_server2 age1ghi...

creation_rules:
  - path_regex: server1/secrets\.yaml$
    key_groups:
      - age:
          - *user_key
          - *host_server1

  - path_regex: server2/secrets\.yaml$
    key_groups:
      - age:
          - *user_key
          - *host_server2
```

## Working with Secrets

### Creating secrets.yaml

The generator creates an unencrypted `secrets.yaml`:

```yaml
admin:
    password_hash: "$6$rounds=..."
nextcloud:
    admin_password: "your-password"
```

### Encrypting Secrets

```bash
cd flake/options
sops --encrypt --in-place secrets.yaml
```

The file is now encrypted:

```yaml
admin:
    password_hash: ENC[AES256_GCM,data:...,type:str]
nextcloud:
    admin_password: ENC[AES256_GCM,data:...,type:str]
sops:
    age:
        - recipient: age1abc...
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
```

### Editing Secrets

SOPS automatically decrypts, opens your editor, and re-encrypts:

```bash
cd flake/options
sops secrets.yaml
```

Or use `sops edit`:

```bash
sops edit secrets.yaml
```

### Viewing Secrets

Decrypt to stdout:

```bash
sops --decrypt secrets.yaml
```

### Adding a New Key

When you add a host key after initial setup:

1. Edit `.sops.yaml` to add the new key
2. Update the secrets file to re-encrypt with the new key:

```bash
sops updatekeys secrets.yaml
```

### Rotating Keys

If a key is compromised:

1. Generate a new key
2. Update `.sops.yaml` with the new key
3. Re-encrypt:

```bash
sops updatekeys secrets.yaml
```

4. Remove the old key from `.sops.yaml`
5. Re-encrypt again:

```bash
sops updatekeys secrets.yaml
```

## Troubleshooting

### "Failed to get the data key"

SOPS can't decrypt. Check:
- Your age key exists at `~/.config/sops/age/keys.txt`
- The key matches one in the encrypted file's `sops.age` section
- Environment variable `SOPS_AGE_KEY_FILE` if using non-default location

### "no matching keys found"

The `.sops.yaml` creation rules don't match the file path:
- Check the `path_regex` patterns
- Ensure `.sops.yaml` is in the correct directory

### Server Can't Decrypt

- Verify the host key in `.sops.yaml` matches the server's key
- Check `/etc/ssh/ssh_host_ed25519_key` exists
- Run `sops updatekeys` after adding the host key

### Permission Denied on Server

sops-nix creates secret files with restricted permissions. If a service can't read:
- Check the secret's owner/group in `modules/secrets.nix`
- Ensure the service user has access

## Best Practices

1. **Never commit unencrypted secrets** - Always encrypt before committing
2. **Back up your age key** - Store it securely outside the repository
3. **Use separate keys per machine** - Each server should have its own host key
4. **Rotate secrets periodically** - Change passwords and re-encrypt
5. **Verify encryption** - Check files are encrypted before pushing

## References

- [SOPS Documentation](https://github.com/getsops/sops)
- [age Documentation](https://github.com/FiloSottile/age)
- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
