{ config, lib, pkgs, opts, ... }:

{
  networking = {
    hostName = opts.hostname;
    domain = opts.domain;

    # NetworkManager off; we want a deterministic static config.
    networkmanager.enable = false;
    useDHCP = false;

    interfaces.${opts.interface} = {
      ipv4.addresses = [{
        address = opts.ipAddress;
        prefixLength = opts.prefixLength;
      }];
    };

    defaultGateway = opts.gateway;

    # Resolve via the locally-running AdGuard Home on 127.0.0.1.
    # Bootstrap nameservers used during early boot before AdGuard is up.
    nameservers = opts.nameservers;

    # Static DNS entries so services on the host can resolve internal names
    # without depending on AdGuard rewrites being healthy.
    hosts = {
      "127.0.0.1" = [ opts.dnsDomain opts.nextcloudDomain ];
    };

    firewall = {
      enable = true;
      allowPing = true;

      # Deny by default
      allowedTCPPorts = [
        opts.sshPort
        opts.dnsPort
        443  # Caddy HTTPS
        opts.adguardPort
      ];
      allowedUDPPorts = [
        opts.dnsPort
      ];

      # Drop everything else, log it.
      logRefusedConnections = true;
    };
  };

  # Disable systemd-resolved; AdGuard binds 127.0.0.1:53.
  services.resolved.enable = false;
}
