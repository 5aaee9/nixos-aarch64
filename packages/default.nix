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
            self.nixosModules.repart-image
            self.nixosModules.firstBoot
            self.nixosModules.apply-overlay
            self.nixosModules.cross
          ] ++ config;
        };
      buildDefaultRepartConfig = kernelModule:
        buildRepartConfig system [ kernelModule ];
      buildDefaultRepartImage = kernelModule:
        (buildDefaultRepartConfig kernelModule).config.system.build.repartImage;

    in
    {
      packages = rec {
        linux-bigtreetech = pkgsCross.callPackage ./bigtreetech-kernel {
          bigtreetechSrc = inputs.bigtreetech-kernel;
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
                dd if=${fastrhino-r68s-uboot}/idbloader.img of=$img seek=64 conv=notrunc status=none
                dd if=${fastrhino-r68s-uboot}/u-boot.itb of=$img seek=16384 conv=notrunc status=none
              '';
            };
          })
        ]).config.system.build.sdImage;

        repart-fastrhino-r68s = buildDefaultRepartImage self.nixosModules.fastrhino-r68s-kernel;

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

        repart-radxa-e20c = buildDefaultRepartImage self.nixosModules.radxa-e20c-kernel;
      };

      checks =
        let
          assertOrThrow = condition: message:
            if condition then true else throw message;
          assertHasKeys = attrs: keys:
            assertOrThrow ((lib.sort lib.lessThan (builtins.attrNames attrs)) == (lib.sort lib.lessThan keys))
              "unexpected repart partition keys";
          plainConfig = module:
            (evalConfig {
              inherit system;
              modules = [
                self.nixosModules.apply-overlay
                self.nixosModules.cross
                module
              ];
            }).config;
          layoutConfig = module:
            (buildDefaultRepartConfig module).config;
          makePlainCheck = name: module:
            let
              cfg = plainConfig module;
              result = assertOrThrow (!(cfg ? sdImage)) "${name} unexpectedly defines sdImage";
            in
            pkgs.runCommand "${name}-plain-module" { } ''
              ${lib.optionalString result "touch $out"}
            '';
          makeLayoutCheck = name: expectedName: cfg:
            let
              partitions = cfg.image.repart.partitions;
              espContents = partitions."10-esp".contents;
              root = cfg.fileSystems."/";
              firmware = cfg.fileSystems."/boot/firmware";
              runtimeRoot = cfg.systemd.repart.partitions."20-root";
              result =
                assertHasKeys partitions [ "00-uboot" "10-esp" "20-root" ]
                && assertOrThrow (cfg.image.baseName == expectedName) "${name}: unexpected image baseName"
                && assertOrThrow (cfg.system.build.repartImage.passthru.outputImage == "sd-image/${expectedName}.raw") "${name}: unexpected wrapper output"
                && assertOrThrow cfg.nixos-aarch64.repartImage.btrfsEsp.enable "${name}: default btrfs/ESP layout disabled"
                && assertOrThrow cfg.nixos-aarch64.repartImage.rockchipUboot.enable "${name}: default Rockchip U-Boot partition disabled"
                && assertOrThrow (cfg.nixos-aarch64.repartImage.postBuildCommands != "") "${name}: missing default U-Boot post-build commands"
                && assertOrThrow (root.device == "/dev/disk/by-label/NIXOS_ROOT" && root.fsType == "btrfs" && root.neededForBoot) "${name}: invalid root filesystem"
                && assertOrThrow (firmware.device == "/dev/disk/by-label/FIRMWARE" && firmware.fsType == "vfat" && builtins.elem "nofail" firmware.options && builtins.elem "noauto" firmware.options) "${name}: invalid firmware filesystem"
                && assertOrThrow (espContents."/EFI/BOOT/BOOTAA64.EFI".source == "${cfg.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi") "${name}: invalid systemd-boot ESP source"
                && assertOrThrow (espContents."/EFI/Linux/${cfg.system.boot.loader.ukiFile}".source == "${cfg.system.build.uki}/${cfg.system.boot.loader.ukiFile}") "${name}: invalid UKI ESP source"
                && assertOrThrow (partitions."20-root".storePaths == [ cfg.system.build.toplevel ]) "${name}: root storePaths missing toplevel"
                && assertOrThrow (runtimeRoot.Type == "root-arm64" && runtimeRoot.Format == "btrfs" && runtimeRoot.Label == "NIXOS_ROOT" && runtimeRoot.SizeMinBytes == "5G" && runtimeRoot.PaddingMinBytes == "0" && runtimeRoot.GrowFileSystem) "${name}: invalid runtime root repart"
                && assertOrThrow cfg.boot.loader.systemd-boot.enable "${name}: systemd-boot disabled"
                && assertOrThrow (!cfg.boot.loader.generic-extlinux-compatible.enable) "${name}: extlinux enabled"
                && assertOrThrow (!(partitions ? "30-store") && !(partitions ? "30-store-a") && !(partitions ? "30-store-b") && !(partitions ? "40-var")) "${name}: unexpected store or var partition";
            in
            pkgs.runCommand "${name}-repart-layout" { } ''
              ${lib.optionalString result "touch $out"}
            '';
          optionConfig = { verify, hydraBuildProduct }:
            (buildRepartConfig system [
              self.nixosModules.radxa-e20c-kernel
              ({ ... }: {
                nixos-aarch64.repartImage = {
                  name = "option-check";
                  postBuildCommands = ''
                    echo "$img" > post-build-img-path
                  '';
                  inherit verify hydraBuildProduct;
                };
              })
            ]).config;
          customRootConfig =
            (buildRepartConfig system [
              self.nixosModules.radxa-e20c-kernel
              ({ config, ... }: {
                nixos-aarch64.repartImage.name = "custom-radxa-e20c";

                fileSystems."/" = {
                  device = "/dev/disk/by-label/CUSTOM_ROOT";
                  fsType = "btrfs";
                  neededForBoot = true;
                };

                systemd.repart.partitions."20-root" = {
                  Type = "root-arm64";
                  Format = "btrfs";
                  Label = "CUSTOM_ROOT";
                  GrowFileSystem = true;
                };

                image.repart = {
                  imageSize = "auto";
                  mkfsOptions.btrfs = [ "--shrink" ];
                  partitions."20-root" = {
                    storePaths = [ config.system.build.toplevel ];
                    repartConfig = {
                      Type = "root-arm64";
                      Format = "btrfs";
                      Label = "CUSTOM_ROOT";
                      SizeMinBytes = "6G";
                      PaddingMinBytes = "0";
                      GrowFileSystem = true;
                    };
                  };
                };
              })
            ]).config;
          verifyOn = optionConfig { verify = true; hydraBuildProduct = true; };
          verifyOff = optionConfig { verify = false; hydraBuildProduct = false; };
          verifyOnCommand = verifyOn.system.build.repartImage.passthru.buildCommand;
          verifyOffCommand = verifyOff.system.build.repartImage.passthru.buildCommand;
          optionResult =
            assertOrThrow (verifyOn.system.build.repartImage.passthru.postBuildCommands != "") "postBuildCommands passthru missing"
            && assertOrThrow (builtins.match ".*img=\\$out/sd-image/option-check.raw.*echo \"\\$img\" > post-build-img-path.*" verifyOnCommand != null) "postBuildCommands missing or not run after img assignment"
            && assertOrThrow (builtins.match ".*sgdisk --verify \"\\$img\".*" verifyOnCommand != null) "verify=true missing sgdisk"
            && assertOrThrow (verifyOn.system.build.repartImage.passthru.nativeBuildInputPaths != [ ]) "verify=true missing native inputs"
            && assertOrThrow (builtins.match ".*nix-support.*hydra-build-products.*" verifyOnCommand != null) "hydra=true missing metadata write"
            && assertOrThrow verifyOn.system.build.repartImage.passthru.verify "verify=true passthru missing"
            && assertOrThrow verifyOn.system.build.repartImage.passthru.hydraBuildProduct "hydra=true passthru missing"
            && assertOrThrow (builtins.match ".*sgdisk --verify \"\\$img\".*" verifyOffCommand == null) "verify=false still includes sgdisk"
            && assertOrThrow (verifyOff.system.build.repartImage.passthru.nativeBuildInputPaths == [ ]) "verify=false still includes native inputs"
            && assertOrThrow (builtins.match ".*nix-support.*hydra-build-products.*" verifyOffCommand == null) "hydra=false still writes metadata"
            && assertOrThrow (!verifyOff.system.build.repartImage.passthru.verify) "verify=false passthru missing"
            && assertOrThrow (!verifyOff.system.build.repartImage.passthru.hydraBuildProduct) "hydra=false passthru missing";
          customRootPartitions = customRootConfig.image.repart.partitions;
          customRootResult =
            assertHasKeys customRootPartitions [ "00-uboot" "10-esp" "20-root" ]
            && assertOrThrow (customRootConfig.image.baseName == "custom-radxa-e20c") "custom root: unexpected image baseName"
            && assertOrThrow (customRootConfig.fileSystems."/".device == "/dev/disk/by-label/CUSTOM_ROOT") "custom root: root filesystem not overridden"
            && assertOrThrow (customRootConfig.systemd.repart.partitions."20-root".Label == "CUSTOM_ROOT") "custom root: runtime root label not overridden"
            && assertOrThrow (customRootPartitions."20-root".repartConfig.Label == "CUSTOM_ROOT") "custom root: image root label not overridden"
            && assertOrThrow (customRootPartitions."20-root".repartConfig.SizeMinBytes == "6G") "custom root: image root size not overridden"
            && assertOrThrow (customRootPartitions."10-esp".repartConfig.Label == "FIRMWARE") "custom root: default ESP missing"
            && assertOrThrow (customRootPartitions."00-uboot".repartConfig.SizeMinBytes == "15M") "custom root: default U-Boot partition missing";
          radxaRepartConfig = layoutConfig self.nixosModules.radxa-e20c-kernel;
          fastrhinoRepartConfig = layoutConfig self.nixosModules.fastrhino-r68s-kernel;
        in
        {
          radxa-e20c-plain-module = makePlainCheck "radxa-e20c" self.nixosModules.radxa-e20c-kernel;
          fastrhino-r68s-plain-module = makePlainCheck "fastrhino-r68s" self.nixosModules.fastrhino-r68s-kernel;
          radxa-e20c-repart-layout = makeLayoutCheck "radxa-e20c" "nixos-radxa-e20c-repart" radxaRepartConfig;
          fastrhino-r68s-repart-layout = makeLayoutCheck "fastrhino-r68s" "nixos-fastrhino-r68s-repart" fastrhinoRepartConfig;
          repart-image-options = pkgs.runCommand "repart-image-options" { } ''
            ${lib.optionalString optionResult "touch $out"}
          '';
          repart-image-custom-root = pkgs.runCommand "repart-image-custom-root" { } ''
            ${lib.optionalString customRootResult "touch $out"}
          '';
        };
    };
}
