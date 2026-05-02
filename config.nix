# User Configuration
# Edit these values for your setup, then deploy with nixos-anywhere or rebuild.

{
  # Network Configuration
  network = {
    serverIP = "192.168.1.100";       # Static IP for this server
    gateway = "192.168.1.1";          # Your router's IP
  };

  # SSH Access
  ssh = {
    # Your SSH public key (required for login)
    # Generate with: ssh-keygen -t ed25519
    publicKey = "ssh-ed25519 AAAA... user@host";
  };

  # GitHub Repository (for auto-upgrades)
  github = {
    username = "your-username";
    repo = "NixOSHome";
  };
}
