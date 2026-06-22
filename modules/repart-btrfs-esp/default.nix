{ config, lib, ... }:

{
  assertions = [
    {
      assertion = config.boot.loader.systemd-boot.enable;
      message = "repart-btrfs-esp requires boot.loader.systemd-boot.enable = true.";
    }
    {
      assertion = !config.boot.loader.generic-extlinux-compatible.enable;
      message = "repart-btrfs-esp requires boot.loader.generic-extlinux-compatible.enable = false.";
    }
  ];

  boot = {
    supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];
    initrd = {
      supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];
      systemd = {
        enable = true;
        repart.enable = true;
      };
    };
    loader = {
      systemd-boot.enable = true;
      generic-extlinux-compatible.enable = lib.mkForce false;
      efi = {
        canTouchEfiVariables = false;
        efiSysMountPoint = "/boot/firmware";
      };
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "btrfs";
    neededForBoot = true;
  };

  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [
      "nofail"
      "noauto"
    ];
  };

  systemd.repart.partitions."20-root" = {
    Type = "root-arm64";
    Format = "btrfs";
    Label = "NIXOS_ROOT";
    SizeMinBytes = "5G";
    PaddingMinBytes = "0";
    GrowFileSystem = true;
  };

  image.repart = {
    imageSize = "auto";
    mkfsOptions.btrfs = [ "--shrink" ];
    partitions = {
      "10-esp" = {
        contents = {
          "/EFI/BOOT/BOOTAA64.EFI".source = "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = "FIRMWARE";
          SizeMinBytes = "128M";
          SizeMaxBytes = "128M";
          PaddingMinBytes = "0";
        };
      };

      "20-root" = {
        storePaths = [ config.system.build.toplevel ];
        repartConfig = {
          Type = "root-arm64";
          Format = "btrfs";
          Label = "NIXOS_ROOT";
          SizeMinBytes = "5G";
          PaddingMinBytes = "0";
          GrowFileSystem = true;
        };
      };
    };
  };
}
