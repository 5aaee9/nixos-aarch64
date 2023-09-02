{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: _: {
      linuxPackages-orangepi-3b = self.linuxPackagesFor self.linux-orangepi-3b;
    })
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ ];
  boot.kernelPackages = pkgs.linuxPackages-orangepi-3b;
  hardware.deviceTree.enable = true;
  boot.consoleLogLevel = lib.mkDefault 7;
  boot.kernelParams = [ "console=ttyS0,1500000" "consoleblank=0" ];
  boot.kernelModules = [ "sprdwl_ng" ];

  boot.initrd.availableKernelModules = lib.mkForce [
    "ext4"
    "sd_mod"
    "sr_mod"
    "mmc_block"
    "ehci_hcd"
    "ohci_hcd"
    "xhci_hcd"
  ];

  fileSystems = {
    # The /boot/firmware filesystem also uses the same block device, but it has the "noauto" option,
    # so it should not b a problem (mounting a vfat file system twice at the same is forbidden).
    "/lib/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [ "ro" "nofail" ];
    };
  };

  systemd.services.systemd-modules-load =
    let
      firmwareMountingService = "lib-firmware.mount";
    in
    {
      wants = [ firmwareMountingService ];
      after = [ firmwareMountingService ];
    };
  # hardware = {
  #   firmware = with pkgs; [
  #     uwe5622-firmware
  #   ];
  # };

  hardware.enableRedistributableFirmware = true;
  hardware.deviceTree.name = "rockchip/rk3566-orangepi-3b.dtb";
}
