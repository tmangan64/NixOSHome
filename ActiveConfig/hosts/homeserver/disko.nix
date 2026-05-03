{ lib, ... }:

{
  disko.devices = {
    disk = {
      # NVMe for OS
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
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

  # SATA HDD for data storage (manually partitioned)
  fileSystems."/srv/data" = {
    device = "/dev/sda1";
    fsType = "ext4";
    options = [ "noatime" ];
  };
}
