{ config, lib, pkgs, ... }:

{
  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernelPackages = pkgs.linuxPackages_5_15;
    consoleLogLevel = lib.mkDefault 7;
    kernelParams = [ "console=ttyS0,115200" "consoleblank=0" ];

    kernelPatches = [
      {
        name = "fly-gemini-makefile";
        patch = ./kernel-arch-arm64-boot-dts-allwinner-Makefile.patch;
      }
      {
        name = "fly-gemini-dts";
        patch = ./kernel-dts-sun50i-h5-fly-gemini.patch;
      }
    ];
  };

  hardware.deviceTree.name = "allwinner/sun50i-h5-fly-gemini.dtb";
  hardware.deviceTree.overlays = [
    {
      name = "uart1";
      dtboFile = ./sun50i-h5-uart1.dtbo;
    }
    {
      name = "uart2";
      dtboFile = ./sun50i-h5-uart2.dtbo;
    }
    {
      name = "usbhost2";
      dtboFile = ./sun50i-h5-usbhost2.dtbo;
    }
    {
      name = "usbhost3";
      dtboFile = ./sun50i-h5-usbhost3.dtbo;
    }
    {
      name = "spidev";
      dtboFile = ./sun50i-h5-spi-spidev.dtbo;
    }
  ];
}
