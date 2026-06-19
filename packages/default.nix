{ self, inputs, ... }:


{
  perSystem = { lib, system, config, pkgs, ... }:
    let

      pkgsCross = import inputs.nixpkgs {
        localSystem = system;
        crossSystem = "aarch64-linux";
      };

      evalConfig = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix";
      buildConfig = hostSystem: config:
        evalConfig {
          system = hostSystem;
          modules = [
            self.nixosModules.firstBoot
            self.nixosModules.sdimage
            self.nixosModules.apply-overlay
            self.nixosModules.cross
          ] ++ config;
        };
      buildRepartConfig = hostSystem: config:
        evalConfig {
          system = hostSystem;
          modules = [
            "${inputs.nixpkgs}/nixos/modules/image/repart.nix"
            "${inputs.nixpkgs}/nixos/modules/system/boot/systemd/repart.nix"
            self.nixosModules.firstBoot
            self.nixosModules.apply-overlay
            self.nixosModules.cross
          ] ++ config;
        };

    in
    {
      packages = rec {
        linux-bigtreetech = pkgsCross.callPackage ./bigtreetech-kernel {
          bigtreetechSrc = inputs.bigtreetech-kernel;
          stdenv = pkgs.gcc9Stdenv;
          kernelPatches = with pkgsCross.kernelPatches; [
            bridge_stp_helper
            request_key_helper
          ];
        };

        uwe5622-firmware = pkgsCross.callPackage ./uwe5622-firmware { };

        linux-orangepi-3b = pkgsCross.callPackage ./orangepi-3b-kernel {
          orangepiSrc = inputs.orangepi-kernel;
          kernelPatches = with pkgsCross.kernelPatches; [
            bridge_stp_helper
            request_key_helper
          ];
        };

        orangepi-3b-uboot = pkgsCross.callPackage ./orangepi-3b-uboot {
          src = inputs.orangepi-uboot;
          inherit (inputs) rkbin;
        };

        panther-x2-uboot = pkgsCross.callPackage ./panther-x2-uboot {
          src = inputs.radxa-uboot;
          rkbin = inputs.rkbin-armbian;
        };

        radxa-e20c-uboot = pkgsCross.callPackage ./radxa-e20c-uboot { };

        fastrhino-r68s-uboot = pkgsCross.callPackage ./fastrhino-r68s-uboot { };

        fly-gemini-uboot = pkgsCross.callPackage ./fly-gemini-uboot { };

        sdimage-fly-gemini = (buildConfig system [
          self.nixosModules.fly-gemini-kernel

          ({ ... }: {
            # TODO: build uboot with nix
            sdImage.extraPostbuild = ''
              dd if="${fly-gemini-uboot}/u-boot-sunxi-with-spl.bin" of="$img" conv=fsync,notrunc bs=1024 seek=8
            '';
          })
        ]).config.system.build.sdImage;

        sdimage-bigtreetech = (buildConfig system [
          self.nixosModules.bigtreetech-kernel

          ({ ... }: {
            # TODO: build uboot with nix
            sdImage.extraPostbuild = ''
              dd if="${./bigtreetech-uboot/u-boot-sunxi-with-spl.bin}" of="$img" conv=fsync,notrunc bs=1024 seek=8
            '';
          })
        ]).config.system.build.sdImage;


        sdimage-orangepi-3b = (buildConfig system [
          self.nixosModules.orangepi-3b-kernel
          ({ ... }: {
            sdImage.compressImage = true;
            sdImage.populateFirmwareCommands = ''
              cp -r ${uwe5622-firmware}/lib/firmware/* firmware/
            '';
            sdImage.extraPostbuild = ''
              dd if=${orangepi-3b-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
              dd if=${orangepi-3b-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
            '';
          })
        ]).config.system.build.sdImage;

        sdimage-panther-x2 = (buildConfig system [
          self.nixosModules.panther-x2-kernel

          ({ ... }: {
            # TODO: enable compress
            # Debug only
            sdImage.firmwarePartitionOffset = 32;
            sdImage.compressImage = false;
            sdImage.extraPostbuild = ''
              dd if=${panther-x2-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
              dd if=${panther-x2-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
            '';
          })
        ]).config.system.build.sdImage;

        sdimage-fastrhino-r68s = (buildConfig system [
          self.nixosModules.fastrhino-r68s-kernel

          ({ ... }: {
            sdImage.extraPostbuild = ''
              dd if=${fastrhino-r68s-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
              dd if=${fastrhino-r68s-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
            '';
          })
        ]).config.system.build.sdImage;

        sdimage-radxa-e20c = (buildConfig system [
          self.nixosModules.radxa-e20c-kernel

          ({ config, lib, ... }: {
            sdImage = {
              firmwarePartitionOffset = lib.mkForce 16;
              firmwareSize = lib.mkForce 128;
              populateRootCommands = lib.mkForce "";
              populateFirmwareCommands = ''
                mkdir -p firmware/EFI/BOOT firmware/EFI/Linux
                install -m 0644 ${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi firmware/EFI/BOOT/BOOTAA64.EFI
                install -m 0644 ${config.system.build.uki}/${config.system.boot.loader.ukiFile} firmware/EFI/Linux/${config.system.boot.loader.ukiFile}
              '';
              extraPostbuild = ''
                dd if=${radxa-e20c-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
                dd if=${radxa-e20c-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
              '';
            };
          })
        ]).config.system.build.sdImage;

        repart-radxa-e20c =
          let
            config = buildRepartConfig system [
              self.nixosModules.radxa-e20c-kernel

              (
                { config, lib, ... }:
                {
                  config = {
                    boot.supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];
                    boot.initrd.supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];
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
                    boot.initrd.systemd.repart.enable = true;
                    systemd.repart.partitions."20-root" = {
                      Type = "root-arm64";
                      Format = "btrfs";
                      Label = "NIXOS_ROOT";
                      SizeMinBytes = "5G";
                      PaddingMinBytes = "0";
                      GrowFileSystem = true;
                    };
                    image.repart = {
                      name = "nixos-radxa-e20c-repart";
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
                  };
                }
              )
            ];
            repartImage = config.config.system.build.image;
          in
          pkgs.runCommand "nixos-radxa-e20c-repart"
            {
              nativeBuildInputs = with pkgs; [
                gptfdisk
              ];
            }
            ''
              mkdir -p $out/sd-image $out/nix-support
              img=$out/sd-image/nixos-radxa-e20c-repart.raw
              install -m 0644 ${repartImage}/nixos-radxa-e20c-repart.raw "$img"

              dd if=${radxa-e20c-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
              dd if=${radxa-e20c-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
              sgdisk --verify $img
              echo "file sd-image $img" >> $out/nix-support/hydra-build-products
            '';
      };
    };
}
