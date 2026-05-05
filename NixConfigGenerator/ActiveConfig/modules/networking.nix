{ config, lib, pkgs, ... }:

{
  networking = {
    hostName = "homeserver";
    domain = "home";

    # NetworkManager off; we want a deterministic static config.
    networkmanager.enable = false;
    useDHCP = false;

    interfaces.enp3s0 = {
      ipv4.addresses = [{
        address = "192.168.0.66";
        prefixLength = 24;
      }];
    };

    defaultGateway = "192.168.0.1";

    # Resolve via the locally-running AdGuard Home on 127.0.0.1.
    # Bootstrap nameservers used during early boot before AdGuard is up.
    nameservers = [ "127.0.0.1" "1.1.1.1" "9.9.9.9" ];

    # Static DNS entries so services on the host can resolve internal names
    # without depending on AdGuard rewrites being healthy.
    hosts = {
      "127.0.0.1" = [ "dns.home" "nas.home" ];
    };

    firewall = {
      enable = true;
      allowPing = true;

      # Deny by default
      allowedTCPPorts = [
        2266  # SSH
        53    # AdGuard DNS
        443   # Caddy HTTPS
        3000  # AdGuard admin UI
      ];
      allowedUDPPorts = [
        53  # AdGuard DNS
      ];

      # Drop everything else, log it.
      logRefusedConnections = true;
    };
  };

  # Disable systemd-resolved; AdGuard binds 127.0.0.1:53.
  services.resolved.enable = false;
}
