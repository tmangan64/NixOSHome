{ lib, userConfig, ... }:

# Single-disk layout. The device path is configured in user-config.nix.

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = userConfig.diskDevice;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "noatime" ];
              };
            };
          };
        };
      };
    };
  };

  # Service data lives on the same disk for now under /var/lib.
  # When a second disk is added, mount it at /srv/data and move state.
}
