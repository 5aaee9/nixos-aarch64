{ lib, ... }:

{
  options.nixos-aarch64 = {
    repartImage = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "nixos-repart";
        description = "Default repart image name used when image.repart.name is not overridden.";
      };

      postBuildCommands = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Shell commands run after copying the raw repart image. The variable img points at the copied image.";
      };

      verify = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to verify the wrapped GPT image with sgdisk.";
      };

      hydraBuildProduct = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to emit Hydra build product metadata for the wrapped image.";
      };

      btrfsEsp.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable the default btrfs root plus ESP repart layout.";
      };

      rockchipUboot.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to reserve the default Rockchip U-Boot loader partition.";
      };
    };

    rockchipUbootRepart.label = lib.mkOption {
      type = lib.types.str;
      default = "E20C_UBOOT";
      description = "GPT label for the reserved Rockchip U-Boot loader partition.";
    };
  };
}
