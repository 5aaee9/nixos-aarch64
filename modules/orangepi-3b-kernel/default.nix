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

  boot.initrd.availableKernelModules = lib.mkForce [
    "ext4"
    "sd_mod"
    "sr_mod"
    "mmc_block"
    "ehci_hcd"
    "ohci_hcd"
    "xhci_hcd"
  ];

  hardware.enableRedistributableFirmware = true;
  hardware.deviceTree.name = "rockchip/rk3566-orangepi-3b.dtb";
}
