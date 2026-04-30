{ config, lib, pkgs, ... }:

# DuckDNS dynamic DNS updater
# Updates your DuckDNS subdomain with your current public IP every 5 minutes.

let
  # Change this to your DuckDNS subdomain (e.g., "myserver" for myserver.duckdns.org)
  subdomain = "barnsfold";
in {
  # Systemd timer to update DuckDNS periodically
  systemd.services.duckdns-update = {
    description = "Update DuckDNS with current public IP";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
    };
    script = ''
      TOKEN=$(cat ${config.sops.secrets."duckdns/token".path})
      ${pkgs.curl}/bin/curl -s "https://www.duckdns.org/update?domains=${subdomain}&token=$TOKEN&ip=" \
        | ${pkgs.gnugrep}/bin/grep -q "OK" && echo "DuckDNS updated successfully" || echo "DuckDNS update failed"
    '';
  };

  systemd.timers.duckdns-update = {
    description = "Update DuckDNS every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
    };
  };
}
