{ lib, pkgs, ... }:

{
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = lib.mkDefault 7;
    kernelParams = [ "console=ttyS0,1500000" "consoleblank=0" ];
  };

  hardware.deviceTree.name = "rockchip/rk3528-radxa-e20c.dtb";

  boot.initrd.availableKernelModules = lib.mkForce [
    "dw_mmc_rockchip"
    "mmc_block"
    "nvme"
    "pcie_rockchip_dw_host"
    "sd_mod"
    "sdhci_of_dwcmshc"
    "xhci_hcd"
  ];

  boot.kernelModules = [
    "dwmac_rk"
    "motorcomm"
    "r8169"
  ];

  hardware.enableRedistributableFirmware = true;
}
