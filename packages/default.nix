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

              ({ config, lib, ... }: {
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
                  fileSystems."/nix" = {
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
                  systemd.repart.partitions."40-var" = {
                    Type = "var";
                    Format = "btrfs";
                    Label = "NIXOS_VAR";
                    SizeMinBytes = "512M";
                    PaddingMinBytes = "0";
                    GrowFileSystem = true;
                  };
                };
              })
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
          in
          pkgs.runCommand "nixos-radxa-e20c-repart"
            {
              nativeBuildInputs = with pkgs; [
                btrfs-progs
                dosfstools
                fakeroot
                gptfdisk
                mtools
                systemd
                util-linux
              ];
            }
            ''
              mkdir -p $out/sd-image $out/nix-support
              img=$out/sd-image/nixos-radxa-e20c-repart.raw
              nixA=$PWD/nixos-a.btrfs

              mkdir -p nix-a-root/store
              while read -r path; do
                cp -a "$path" nix-a-root/store/
              done < ${closureInfo}/store-paths

              truncate -s 8G "$nixA"
              fakeroot mkfs.btrfs \
                --force \
                --label NIXOS_A \
                --compress zstd:6 \
                --shrink \
                --rootdir nix-a-root \
                "$nixA"
              test "$(stat -c %s "$nixA")" -le "4294967296"

              mkdir -p repart.d
              cat > repart.d/10-esp.conf <<EOF
              [Partition]
              Type=esp
              Format=vfat
              Label=FIRMWARE
              SizeMinBytes=128M
              SizeMaxBytes=128M
              PaddingMinBytes=0
              CopyFiles=${config.config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi:/EFI/systemd/systemd-bootaa64.efi
              CopyFiles=${config.config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi:/EFI/BOOT/BOOTAA64.EFI
              CopyFiles=${config.config.boot.kernelPackages.kernel}/${config.config.system.boot.loader.kernelFile}:/EFI/nixos/kernel.efi
              CopyFiles=${config.config.system.build.initialRamdisk}/${config.config.system.boot.loader.initrdFile}:/EFI/nixos/initrd.efi
              CopyFiles=${config.config.hardware.deviceTree.package}/${config.config.hardware.deviceTree.name}:/EFI/nixos/devicetree.dtb
              CopyFiles=${loaderConf}:/loader/loader.conf
              CopyFiles=${loaderEntry}:/loader/entries/nixos.conf
              EOF

              cat > repart.d/20-nix-a.conf <<EOF
              [Partition]
              Type=root
              Label=NIXOS_A
              CopyBlocks=$nixA
              SizeMinBytes=4G
              SizeMaxBytes=4G
              PaddingMinBytes=0
              EOF

              cat > repart.d/30-nix-b.conf <<EOF
              [Partition]
              Type=root
              Format=btrfs
              Label=NIXOS_B
              SizeMinBytes=4G
              SizeMaxBytes=4G
              PaddingMinBytes=0
              EOF

              cat > repart.d/40-var.conf <<EOF
              [Partition]
              Type=var
              Format=btrfs
              Label=NIXOS_VAR
              SizeMinBytes=512M
              PaddingMinBytes=0
              GrowFileSystem=yes
              EOF

              fakeroot systemd-repart \
                --architecture=arm64 \
                --dry-run=no \
                --empty=create \
                --size=auto \
                --definitions=repart.d \
                --json=pretty \
                $img

              dd if=${radxa-e20c-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
              dd if=${radxa-e20c-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
              sgdisk --verify $img
              echo "file sd-image $img" >> $out/nix-support/hydra-build-products
            '';
      };
    };
}
