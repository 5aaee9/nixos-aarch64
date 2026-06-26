{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  cfg = config.nixos-aarch64.repartImage;
  imagePath = "${config.system.build.image}/${config.image.filePath}";
  outputImage = "$out/sd-image/${config.image.baseName}.raw";
  nativeBuildInputs = lib.optional cfg.verify pkgs.gptfdisk;
  esp = import ../systemd-boot-esp-contents.nix { inherit config lib pkgs; };
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

      system.build.repartImage = pkgs.runCommand config.image.baseName {
        inherit nativeBuildInputs;
        passthru = {
          inherit imagePath;
          inherit buildCommand nativeBuildInputs;
          nativeBuildInputPaths = map toString nativeBuildInputs;
          outputImage = "sd-image/${config.image.baseName}.raw";
          inherit (cfg) hydraBuildProduct postBuildCommands verify;
        };
      } buildCommand;
    }

    (lib.mkIf cfg.btrfsEsp.enable {
      boot = {
        supportedFilesystems = lib.mkDefault [
          "vfat"
          "btrfs"
        ];
        initrd = {
          supportedFilesystems = lib.mkDefault [
            "vfat"
            "btrfs"
          ];

          systemd = {
            enable = lib.mkDefault true;
            repart.enable = lib.mkDefault true;
          };
        };

        loader = {
          systemd-boot.enable = lib.mkDefault true;
          generic-extlinux-compatible.enable = lib.mkDefault false;
          efi = {
            canTouchEfiVariables = lib.mkDefault false;
            efiSysMountPoint = lib.mkDefault "/boot/firmware";
          };
        };
      };

      fileSystems."/" = {
        device = lib.mkDefault "/dev/disk/by-label/NIXOS_ROOT";
        fsType = lib.mkDefault "btrfs";
        neededForBoot = lib.mkDefault true;
      };

      fileSystems."/boot/firmware" = {
        device = lib.mkDefault "/dev/disk/by-label/FIRMWARE";
        fsType = lib.mkDefault "vfat";
        neededForBoot = lib.mkDefault true;
      };

      systemd.repart.partitions."20-root" = {
        Type = lib.mkDefault "root-arm64";
        Format = lib.mkDefault "btrfs";
        Label = lib.mkDefault "NIXOS_ROOT";
        SizeMinBytes = lib.mkDefault "5G";
        PaddingMinBytes = lib.mkDefault "0";
        GrowFileSystem = lib.mkDefault true;
      };

      image.repart = {
        imageSize = lib.mkDefault "auto";
        mkfsOptions.btrfs = lib.mkDefault [ "--shrink" ];
        partitions = {
          "10-esp" = {
            contents = lib.mapAttrs (_: content: { source = lib.mkDefault content.source; }) esp.contents;
            repartConfig = {
              Type = lib.mkDefault "esp";
              Format = lib.mkDefault "vfat";
              Label = lib.mkDefault "FIRMWARE";
              SizeMinBytes = lib.mkDefault "128M";
              SizeMaxBytes = lib.mkDefault "128M";
              PaddingMinBytes = lib.mkDefault "0";
            };
          };

          "20-root" = {
            storePaths = lib.mkDefault [ config.system.build.toplevel ];
            repartConfig = {
              Type = lib.mkDefault "root-arm64";
              Format = lib.mkDefault "btrfs";
              Label = lib.mkDefault "NIXOS_ROOT";
              SizeMinBytes = lib.mkDefault "5G";
              PaddingMinBytes = lib.mkDefault "0";
              GrowFileSystem = lib.mkDefault true;
            };
          };
        };
      };
    })

    (lib.mkIf cfg.rockchipUboot.enable {
      image.repart.partitions."00-uboot".repartConfig = {
        Type = lib.mkDefault "8DA63339-0007-60C0-C436-083AC8230908";
        Label = lib.mkDefault config.nixos-aarch64.rockchipUbootRepart.label;
        SizeMinBytes = lib.mkDefault "15M";
        SizeMaxBytes = lib.mkDefault "15M";
        PaddingMinBytes = lib.mkDefault "0";
      };
    })
  ];
}
