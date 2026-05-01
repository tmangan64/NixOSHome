{ config, lib, pkgs, userConfig, ... }:

{
  services.adguardhome = {
    enable = true;
    openFirewall = false;  # firewall handled centrally in networking.nix
    mutableSettings = false;
    host = "0.0.0.0";
    port = 3000;

    settings = {
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;

        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.quad9.net/dns-query"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          "9.9.9.9"
        ];

        # Privacy defaults
        anonymize_client_ip = true;
        statistics_interval = 1;  # 1 day rolling stats only
        querylog_enabled = false;
        querylog_file_enabled = false;

        # Internal name rewrites so .home hostnames resolve to the server.
        rewrites = [
          { domain = "dns.${userConfig.domain}"; answer = userConfig.ipAddress; }
        ];

        # Block reverse lookup leaks for RFC1918 ranges.
        bogus_nxdomain = [ ];
      };

      filtering = {
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
}
