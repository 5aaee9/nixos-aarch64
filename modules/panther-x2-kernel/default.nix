{ config, lib, pkgs, ... }:

{
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = lib.mkDefault 7;
    kernelParams = [ "console=ttyS2,1500000" "consoleblank=0" ];

    kernelPatches = [
      {
        name = "add-board-panther-x2";
        patch = ./add-board-panther-x2.patch;
      }
    ];
  };

  hardware.deviceTree.name = "rockchip/rk3566-panther-x2.dtb";
}
