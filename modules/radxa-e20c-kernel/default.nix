{ config, lib, pkgs, ... }:

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

  sdImage = {
    firmwarePartitionOffset = lib.mkForce 16;
    firmwareSize = lib.mkForce 128;
    populateRootCommands = lib.mkForce "";
    populateFirmwareCommands = lib.mkForce ''
      mkdir -p \
        firmware/EFI/BOOT \
        firmware/EFI/systemd \
        firmware/EFI/nixos \
        firmware/loader/entries

      install -m 0644 ${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi firmware/EFI/systemd/systemd-bootaa64.efi
      cp firmware/EFI/systemd/systemd-bootaa64.efi firmware/EFI/BOOT/BOOTAA64.EFI

      install -m 0644 ${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile} firmware/EFI/nixos/kernel.efi
      install -m 0644 ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} firmware/EFI/nixos/initrd.efi
      install -m 0644 ${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name} firmware/EFI/nixos/devicetree.dtb

      cat > firmware/loader/loader.conf <<EOF
      timeout 1
      default nixos.conf
      editor 0
      console-mode keep
      EOF

      cat > firmware/loader/entries/nixos.conf <<EOF
      title NixOS
      sort-key nixos
      version ${config.system.nixos.label}
      linux /EFI/nixos/kernel.efi
      initrd /EFI/nixos/initrd.efi
      options init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
      devicetree /EFI/nixos/devicetree.dtb
      EOF
    '';
  };
}
