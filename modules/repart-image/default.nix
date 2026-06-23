{ config
, lib
, pkgs
, modulesPath
, ...
}:

let
  cfg = config.nixos-aarch64.repartImage;
  imagePath = "${config.system.build.image}/${config.image.filePath}";
  outputImage = "$out/sd-image/${config.image.baseName}.raw";
  nativeBuildInputs = lib.optional cfg.verify pkgs.gptfdisk;
  buildCommand = ''
    mkdir -p $out/sd-image
    img=${outputImage}
    install -m 0644 ${imagePath} "$img"

    ${cfg.postBuildCommands}

    ${lib.optionalString cfg.verify ''
      sgdisk --verify "$img"
    ''}
    ${lib.optionalString cfg.hydraBuildProduct ''
      mkdir -p $out/nix-support
      echo "file sd-image $img" >> $out/nix-support/hydra-build-products
    ''}
  '';
in
{
  imports = [
    ../repart-options
    "${modulesPath}/image/repart.nix"
    "${modulesPath}/system/boot/systemd/repart.nix"
  ];

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.system.build ? image;
          message = "nixos-aarch64.repartImage requires upstream system.build.image from the repart image module.";
        }
        {
          assertion = config.image.extension == "raw";
          message = "nixos-aarch64.repartImage only supports raw uncompressed repart images.";
        }
        {
          assertion = !cfg.rockchipUboot.enable || cfg.postBuildCommands != "";
          message = "nixos-aarch64.repartImage.rockchipUboot.enable requires postBuildCommands that write the Rockchip loader.";
        }
      ];

      image.repart = {
        name = lib.mkDefault cfg.name;
        compression.enable = lib.mkDefault false;
      };

      system.build.repartImage = pkgs.runCommand config.image.baseName
        {
          inherit nativeBuildInputs;
          passthru = {
            inherit imagePath;
            inherit buildCommand nativeBuildInputs;
            nativeBuildInputPaths = map toString nativeBuildInputs;
            outputImage = "sd-image/${config.image.baseName}.raw";
            inherit (cfg) hydraBuildProduct postBuildCommands verify;
          };
        }
        buildCommand;
    }

    (lib.mkIf cfg.btrfsEsp.enable {
      assertions = [
        {
          assertion = config.boot.loader.systemd-boot.enable;
          message = "nixos-aarch64.repartImage.btrfsEsp.enable requires boot.loader.systemd-boot.enable = true.";
        }
        {
          assertion = !config.boot.loader.generic-extlinux-compatible.enable;
          message = "nixos-aarch64.repartImage.btrfsEsp.enable requires boot.loader.generic-extlinux-compatible.enable = false.";
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
    })

    (lib.mkIf cfg.rockchipUboot.enable {
      image.repart.partitions."00-uboot".repartConfig = {
        Type = "8DA63339-0007-60C0-C436-083AC8230908";
        Label = config.nixos-aarch64.rockchipUbootRepart.label;
        SizeMinBytes = "15M";
        SizeMaxBytes = "15M";
        PaddingMinBytes = "0";
      };
    })
  ];
}
