package nixgen.generator.templates;

import nixgen.model.ConfigData;

public class NetworkingTemplate {
    public static String generate(ConfigData config) {
        return String.format("""
{ config, lib, pkgs, ... }:

{
  networking = {
    hostName = "%s";
    domain = "%s";

    # NetworkManager off; we want a deterministic static config.
    networkmanager.enable = false;
    useDHCP = false;

    interfaces.%s = {
      ipv4.addresses = [{
        address = "%s";
        prefixLength = %d;
      }];
    };

    defaultGateway = "%s";

    # Resolve via the locally-running AdGuard Home on 127.0.0.1.
    # Bootstrap nameservers used during early boot before AdGuard is up.
    nameservers = [ "127.0.0.1" "1.1.1.1" "9.9.9.9" ];

    # Static DNS entries so services on the host can resolve internal names
    # without depending on AdGuard rewrites being healthy.
    hosts = {
      "127.0.0.1" = [ "%s" "%s" ];
    };

    firewall = {
      enable = true;
      allowPing = true;

      # Deny by default
      allowedTCPPorts = [
        %d  # SSH
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
""", config.getHostname(), config.getDomain(), config.getNetworkInterface(),
     config.getStaticIp(), config.getPrefixLength(), config.getGateway(),
     config.getDnsDomain(), config.getNasDomain(), config.getSshPort());
    }
}
