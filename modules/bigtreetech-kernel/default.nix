{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: _: {
      linuxPackages-bigtreetech = self.linuxPackagesFor self.linux-bigtreetech;
    })
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ rtl8189fs ];
  boot.kernelPackages = pkgs.linuxPackages-bigtreetech;
  hardware.deviceTree.enable = true;
  boot.consoleLogLevel = lib.mkDefault 7;
  boot.kernelParams = [ "console=ttyS0,115200" "consoleblank=0" ];

  boot.initrd.availableKernelModules = lib.mkForce [
    "ext4"
    "sunxi-mmc"
    "axp20x-ac-power"
    "axp20x-battery"
    "sd_mod"
    "sr_mod"
    "mmc_block"
    "ehci_hcd"
    "ohci_hcd"
    "xhci_hcd"
  ];

  hardware.enableRedistributableFirmware = true;
  hardware.deviceTree.name = "allwinner/sun50i-h616-bigtreetech-cb1-sd.dtb";
}
