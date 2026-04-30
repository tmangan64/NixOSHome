{ config, lib, pkgs, ... }:

{
  # Enable IP forwarding for WireGuard peer-to-LAN access.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets."wireguard/private_key".path;

    # Add peer entries here. Each peer needs its own publicKey and a unique
    # IP within 10.100.0.0/24.
    peers = [
      {
        # Laptop
        publicKey = "44X38kf/b94+D9eR+02QqzTKxl3PoprYO16dUF9uy2c=";
        allowedIPs = [ "10.100.0.2/32" ];
      }
    ];

    # NAT outbound traffic from peers so they can reach the LAN through this host.
    postSetup = ''
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o enp3s0 -j MASQUERADE
    '';
    postShutdown = ''
      ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o enp3s0 -j MASQUERADE
    '';
  };
}
