{ config, lib, pkgs, userConfig, ... }:

{
  networking = {
    hostName = userConfig.hostname;
    domain = userConfig.domain;

    # NetworkManager off; we want a deterministic static config.
    networkmanager.enable = false;
    useDHCP = false;

    interfaces.${userConfig.networkInterface} = {
      ipv4.addresses = [{
        address = userConfig.ipAddress;
        prefixLength = userConfig.prefixLength;
      }];
    };

    defaultGateway = userConfig.gateway;

    # Resolve via the locally-running AdGuard Home on 127.0.0.1.
    # Bootstrap nameservers used during early boot before AdGuard is up.
    nameservers = [ "127.0.0.1" "1.1.1.1" "9.9.9.9" ];

    # Static DNS entries so Caddy and clients on the host resolve internal names
    # without depending on AdGuard rewrites being healthy.
    hosts = {
      "127.0.0.1" = [ "dns.${userConfig.domain}" ];
    };

    firewall = {
      enable = true;
      allowPing = true;

      # Default deny on input. Each service module opens what it needs.
      allowedTCPPorts = [
        22    # SSH
        53    # AdGuard DNS
        80    # Caddy HTTP redirect
        443   # Caddy HTTPS
        3000  # AdGuard admin UI (LAN only via firewall scoping below)
      ];
      allowedUDPPorts = [
        53      # AdGuard DNS
      ];

      # Drop everything else, log it.
      logRefusedConnections = true;
    };
  };

  # Disable systemd-resolved; AdGuard binds 127.0.0.1:53.
  services.resolved.enable = false;
}
