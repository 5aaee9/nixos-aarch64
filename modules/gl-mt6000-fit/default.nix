{ config, pkgs, ... }:

{
  system.build.mt6000Fit =
    pkgs.runCommand "gl-mt6000-fit"
      {
        nativeBuildInputs = [
          pkgs.ubootTools
          pkgs.dtc
        ];
      }
      ''
            cat > image.its <<'EOF'
        /dts-v1/;
        / {
          description = "NixOS GL-MT6000 FIT image";
          #address-cells = <1>;

          images {
            kernel {
              description = "NixOS Linux kernel";
              data = /incbin/("kernel.gz");
              type = "kernel";
              arch = "arm64";
              os = "linux";
              compression = "gzip";
              load = <0x46000000>;
              entry = <0x46000000>;
              hash-1 { algo = "sha256"; };
            };

            ramdisk {
              description = "NixOS initrd";
              data = /incbin/("initrd.gz");
              type = "ramdisk";
              arch = "arm64";
              os = "linux";
              compression = "gzip";
              hash-1 { algo = "sha256"; };
            };

            fdt {
              description = "GL-MT6000 device tree";
              data = /incbin/("${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}");
              type = "flat_dt";
              arch = "arm64";
              compression = "none";
              hash-1 { algo = "sha256"; };
            };
          };

          configurations {
            default = "conf";
            conf {
              kernel = "kernel";
              ramdisk = "ramdisk";
              fdt = "fdt";
            };
          };
        };
        EOF
            gzip -n -c "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}" > kernel.gz
            gzip -n -c "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}" > initrd.gz
            mkimage -f image.its $out
      '';
}
