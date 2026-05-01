{ config, lib, pkgs, modulesPath, userConfig, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];

  # KVM module based on CPU vendor
  boot.kernelModules =
    if userConfig.cpuVendor == "intel" then [ "kvm-intel" ]
    else if userConfig.cpuVendor == "amd" then [ "kvm-amd" ]
    else [ ];
  boot.extraModulePackages = [ ];

  # CPU microcode based on vendor
  hardware.cpu.intel.updateMicrocode =
    lib.mkIf (userConfig.cpuVendor == "intel")
      (lib.mkDefault config.hardware.enableRedistributableFirmware);
  hardware.cpu.amd.updateMicrocode =
    lib.mkIf (userConfig.cpuVendor == "amd")
      (lib.mkDefault config.hardware.enableRedistributableFirmware);
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = lib.mkDefault userConfig.platform;

  # After first nixos-anywhere deploy, regenerate this with:
  #   nixos-generate-config --show-hardware-config --root /mnt
  # and replace this file with the output for an exact hardware match.
}
