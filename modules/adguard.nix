{ config, lib, pkgs, ... }:

let
  # Used to trigger a restart when settings change
  settingsFormat = pkgs.formats.yaml { };
  configFile = settingsFormat.generate "AdGuardHome.yaml" config.services.adguardhome.settings;
in
{
  services.adguardhome = {
    enable = true;
    openFirewall = false;  # firewall handled centrally in networking.nix
    mutableSettings = false;
    host = "0.0.0.0";
    port = 3000;

    settings = {
      dns = {
        # Bind to specific interfaces to avoid conflict with Podman's aardvark-dns on 10.89.0.1
        bind_hosts = [ "127.0.0.1" "192.168.0.66" ];
        port = 53;

        # Disable rate limiting for home network (default is 20 req/s per client)
        ratelimit = 0;

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

        # Don't use /etc/hosts - we manage internal names via rewrites.
        hostsfile_enabled = false;

        # Block reverse lookup leaks for RFC1918 ranges.
        bogus_nxdomain = [ ];
      };

      filtering = {
        # Internal name rewrites so .home hostnames resolve to the server.
        rewrites = [
          { domain = "dns.home"; answer = "192.168.0.66"; enabled = true; }
          { domain = "nas.home"; answer = "192.168.0.66"; enabled = true; }
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

  # Restart AdGuard when settings change
  systemd.services.adguardhome.restartTriggers = [ configFile ];
}
