{ self, inputs, ... }:


{
  perSystem = { lib, system, config, pkgs, ... }: let

    pkgsCross = import inputs.nixpkgs {
      localSystem = system;
      crossSystem = "aarch64-linux";
    };

    evalConfig = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix";
    buildConfig = hostSystem: config:
      evalConfig {
        system = hostSystem;
        modules = [
          self.nixosModules.cross
        ] ++ config;
      };

  in {
    packages = {
      sdimage-bigtreetech = (buildConfig system [
        self.nixosModules.firstBoot
        self.nixosModules.sdimage
        self.nixosModules.apply-overlay
        self.nixosModules.bigtreetech-kernel
        ({ ... }: {
          # TODO: build uboot with nix
          sdImage.extraPostbuild = ''
            dd if="${./bigtreetech-uboot/u-boot-sunxi-with-spl.bin}" of="$img" conv=fsync,notrunc bs=1024 seek=8
          '';

          boot.initrd.systemd = {
            enable = true;
            emergencyAccess = true;
            initrdBin = with pkgs; [ gnugrep strace ]; # for debugging only
          };
        })
      ]).config.system.build.sdImage;

    };
  };
}
