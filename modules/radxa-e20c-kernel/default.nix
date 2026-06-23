{ lib, pkgs, ... }:

{
  imports = [ ../repart-options ];

  nixos-aarch64.repartImage = {
    name = lib.mkDefault "nixos-radxa-e20c-repart";
    btrfsEsp.enable = lib.mkDefault true;
    rockchipUboot.enable = lib.mkDefault true;
    postBuildCommands = lib.mkDefault (lib.optionalString (pkgs ? radxa-e20c-uboot) ''
      dd if=${pkgs.radxa-e20c-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
      dd if=${pkgs.radxa-e20c-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
    '');
  };

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = lib.mkForce false;
      systemd-boot = {
        enable = true;
        editor = false;
        consoleMode = "keep";
      };
      efi = {
        canTouchEfiVariables = false;
        efiSysMountPoint = "/boot/firmware";
      };
      timeout = 1;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = lib.mkDefault 7;
    kernelParams = [ "console=ttyS0,1500000" "consoleblank=0" ];
  };

  hardware.deviceTree = {
    enable = true;
    name = "rockchip/rk3528-radxa-e20c.dtb";
  };

  boot.initrd.availableKernelModules = lib.mkForce [
    "dw_mmc_rockchip"
    "mmc_block"
    "nvme"
    "pcie_rockchip_host"
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
