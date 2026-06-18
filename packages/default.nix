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

        sdimage-radxa-e20c = (buildConfig system [
          self.nixosModules.radxa-e20c-kernel

          ({ ... }: {
            sdImage.extraPostbuild = ''
              dd if=${radxa-e20c-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
              dd if=${radxa-e20c-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
            '';
          })
        ]).config.system.build.sdImage;

        repart-radxa-e20c =
          let
            config = buildRepartConfig system [
              self.nixosModules.radxa-e20c-kernel

              (
                { config, lib, pkgs, ... }:
                let
                  e20cRepartScript = pkgs.writeShellScript "e20c-repart-grow-var" ''
                    set -eu

                    varPartition="$(readlink -f /dev/disk/by-label/NIXOS_VAR)"
                    varPartitionName="$(basename "$varPartition")"
                    disk="/dev/$(basename "$(readlink -f "/sys/class/block/$varPartitionName/..")")"

                    exec ${config.boot.initrd.systemd.package}/bin/systemd-repart \
                      --definitions=/etc/repart.d \
                      --dry-run=no \
                      --empty=refuse \
                      --discard=true \
                      "$disk"
                  '';
                in
                {
                  options.sdImage = lib.mkOption {
                    type = lib.types.attrs;
                    default = { };
                    visible = false;
                  };

                  config = {
                    sdImage = lib.mkForce { };
                    boot.supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];
                    boot.initrd.supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];
                    fileSystems."/" = {
                      device = "tmpfs";
                      fsType = "tmpfs";
                      options = [
                        "mode=755"
                        "size=512M"
                      ];
                    };
                    fileSystems."/nix/store" = {
                      device = "/dev/disk/by-label/NIXOS_A";
                      fsType = "btrfs";
                      neededForBoot = true;
                      options = [ "ro" ];
                    };
                    fileSystems."/var" = {
                      device = "/dev/disk/by-label/NIXOS_VAR";
                      fsType = "btrfs";
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
                    boot.initrd.systemd.storePaths = [ e20cRepartScript ];
                    boot.initrd.systemd.services.systemd-repart = {
                      after = lib.mkForce [ "dev-disk-by\\x2dlabel-NIXOS_VAR.device" ];
                      requires = [ "dev-disk-by\\x2dlabel-NIXOS_VAR.device" ];
                      serviceConfig.ExecStart = lib.mkForce [
                        ""
                        "${e20cRepartScript}"
                      ];
                    };
                    systemd.repart.partitions."40-var" = {
                      Type = "var";
                      Format = "btrfs";
                      Label = "NIXOS_VAR";
                      SizeMinBytes = "512M";
                      PaddingMinBytes = "0";
                      GrowFileSystem = true;
                    };
                    image.repart = {
                      name = "nixos-radxa-e20c-repart";
                      imageSize = "auto";
                      partitions = {
                        "10-esp" = {
                          contents = {
                            "/EFI/systemd/systemd-bootaa64.efi".source = "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
                            "/EFI/BOOT/BOOTAA64.EFI".source = "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
                            "/EFI/nixos/kernel.efi".source = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
                            "/EFI/nixos/initrd.efi".source = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
                            "/EFI/nixos/devicetree.dtb".source = "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
                            "/loader/loader.conf".source = loaderConf;
                            "/loader/entries/nixos.conf".source = loaderEntry;
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
                        "20-nix-a" = {
                          repartConfig = {
                            Type = "root-arm64";
                            Label = "NIXOS_A";
                            CopyBlocks = "/build/nixos-a.btrfs";
                            SizeMinBytes = "4G";
                            SizeMaxBytes = "4G";
                            PaddingMinBytes = "0";
                          };
                        };
                        "30-nix-b" = {
                          repartConfig = {
                            Type = "root-arm64";
                            Format = "btrfs";
                            Label = "NIXOS_B";
                            SizeMinBytes = "4G";
                            SizeMaxBytes = "4G";
                            PaddingMinBytes = "0";
                          };
                        };
                        "40-var" = {
                          repartConfig = {
                            Type = "var";
                            Format = "btrfs";
                            Label = "NIXOS_VAR";
                            SizeMinBytes = "512M";
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
            closureInfo = pkgs.closureInfo {
              rootPaths = [ config.config.system.build.toplevel ];
            };
            loaderConf = pkgs.writeText "loader.conf" ''
              timeout 1
              default nixos.conf
              editor 0
              console-mode keep
            '';
            loaderEntry = pkgs.writeText "nixos.conf" ''
              title NixOS
              sort-key nixos
              version ${config.config.system.nixos.label}
              linux /EFI/nixos/kernel.efi
              initrd /EFI/nixos/initrd.efi
              options init=${config.config.system.build.toplevel}/init ${toString config.config.boot.kernelParams}
              devicetree /EFI/nixos/devicetree.dtb
            '';
            repartImage = config.config.system.build.image.overrideAttrs (old: {
              prePatch = (old.prePatch or "") + ''
                mkdir -p nix-a-root
                while read -r path; do
                  install -d "nix-a-root/$(dirname "''${path#/nix/store/}")"
                  cp -a "$path" "nix-a-root/''${path#/nix/store/}"
                done < ${closureInfo}/store-paths

                truncate -s 8G nixos-a.btrfs
                fakeroot mkfs.btrfs \
                  --force \
                  --label NIXOS_A \
                  --compress zstd:6 \
                  --shrink \
                  --rootdir nix-a-root \
                  nixos-a.btrfs
                test "$(stat -c %s nixos-a.btrfs)" -le "4294967296"
              '';
            });
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
