{ config, lib, pkgs, userConfig, ... }:

let
  settingsFormat = pkgs.formats.yaml { };
  configFile = settingsFormat.generate "AdGuardHome.yaml" config.services.adguardhome.settings;
in
{
  services.adguardhome = {
    enable = true;
    openFirewall = false;
    mutableSettings = false;
    host = "0.0.0.0";
    port = 3000;

    settings = {
      dns = {
        bind_hosts = [ "127.0.0.1" userConfig.network.serverIP ];
        port = 53;

        ratelimit = 10;

        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.quad9.net/dns-query"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          "9.9.9.9"
        ];

        anonymize_client_ip = true;
        statistics_interval = 1;
        querylog_enabled = false;
        querylog_file_enabled = false;

        hostsfile_enabled = false;

        bogus_nxdomain = [ ];
      };

      filtering = {
        rewrites = [
          { domain = "dns.home"; answer = userConfig.network.serverIP; enabled = true; }
          { domain = "nas.home"; answer = userConfig.network.serverIP; enabled = true; }
        ];
        protection_enabled = true;
        filtering_enabled = true;
        parental_enabled = false;
        safesearch_enabled = false;
      };

      filters = [
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard DNS filter";
          id = 1;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
          name = "AdAway Default Blocklist";
          id = 2;
        }
      ];

      user_rules = [ ];
    };
  };

  systemd.services.adguardhome.restartTriggers = [ configFile ];
}
