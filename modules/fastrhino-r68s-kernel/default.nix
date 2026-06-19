{ lib, pkgs, ... }:

{
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = lib.mkDefault 7;
    kernelParams = [ "console=ttyS2,1500000" "consoleblank=0" ];

    initrd.availableKernelModules = lib.mkForce [
      "ext4"
      "sd_mod"
      "sr_mod"
      "mmc_block"
      "ehci_hcd"
      "ohci_hcd"
      "xhci_hcd"
      "phy_rockchip_inno_usb2"
      "phy_rockchip_naneng_combphy"
      "pcie_rockchip_dw_host"
      "rk808"
      "dw_mmc_rockchip"
    ];
  };

  hardware.deviceTree.name = "rockchip/rk3568-fastrhino-r68s.dtb";
  hardware.enableRedistributableFirmware = true;
}
