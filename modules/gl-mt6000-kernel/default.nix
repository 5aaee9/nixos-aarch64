{ lib, pkgs, ... }:

{
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelPatches = [
      {
        name = "mt7986a-glinet-gl-mt6000-dts";
        patch = ./mt7986a-glinet-gl-mt6000.patch;
      }
    ];
    consoleLogLevel = lib.mkDefault 7;
    kernelParams = [
      "console=ttyS0,115200"
      "consoleblank=0"
    ];
    initrd.availableKernelModules = lib.mkForce [
      "mmc_block"
      "mmc_core"
      "sdhci"
      "xhci_hcd"
    ];
  };

  hardware.deviceTree = {
    enable = true;
    name = "mediatek/mt7986a-glinet-gl-mt6000.dtb";
  };

  hardware.enableRedistributableFirmware = true;
}
