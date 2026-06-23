{ lib, pkgs, ... }:

let
  systemdUkiStub = pkgs.systemd.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ./systemd-boot-arm64-align-kernel.patch
    ];
  });
in
{
  imports = [ ../repart-options ];

  nixos-aarch64.repartImage = {
    name = lib.mkDefault "nixos-fastrhino-r68s-repart";
    btrfsEsp.enable = lib.mkDefault true;
    rockchipUboot.enable = lib.mkDefault true;
    postBuildCommands = lib.mkDefault (lib.optionalString (pkgs ? fastrhino-r68s-uboot) ''
      dd if=${pkgs.fastrhino-r68s-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
      dd if=${pkgs.fastrhino-r68s-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
    '');
  };

  boot = {
    uki.settings.UKI.Stub = "${systemdUkiStub}/lib/systemd/boot/efi/linuxaa64.efi.stub";

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
      "pcie_rockchip_host"
      "dw_mmc_rockchip"
    ];
  };

  hardware.deviceTree = {
    enable = true;
    name = "rockchip/rk3568-fastrhino-r68s.dtb";
  };

  hardware.enableRedistributableFirmware = true;
}
