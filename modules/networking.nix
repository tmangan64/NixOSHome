{ config, lib, pkgs, userConfig, ... }:

{
  networking = {
    hostName = "homeserver";
    domain = "home";

    networkmanager.enable = false;
    useDHCP = false;

    interfaces.enp3s0 = {
      ipv4.addresses = [{
        address = userConfig.network.serverIP;
        prefixLength = 24;
      }];
    };

    defaultGateway = userConfig.network.gateway;

    nameservers = [ "127.0.0.1" "1.1.1.1" "9.9.9.9" ];

    hosts = {
      "127.0.0.1" = [ "dns.home" "nas.home" ];
    };

    firewall = {
      enable = true;
      allowPing = true;

      allowedTCPPorts = [
        2266  # SSH
        53    # AdGuard DNS
        443   # Caddy HTTPS
        3000  # AdGuard admin UI
      ];
      allowedUDPPorts = [
        53  # AdGuard DNS
      ];

      logRefusedConnections = true;
    };
  };

  services.resolved.enable = false;
}
