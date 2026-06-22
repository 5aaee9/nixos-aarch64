{ config, lib, ... }:

{
  options.nixos-aarch64.rockchipUbootRepart.label = lib.mkOption {
    type = lib.types.str;
    default = "E20C_UBOOT";
    description = "GPT label for the reserved Rockchip U-Boot loader partition.";
  };

  config.image.repart.partitions."00-uboot".repartConfig = {
    Type = "8DA63339-0007-60C0-C436-083AC8230908";
    Label = config.nixos-aarch64.rockchipUbootRepart.label;
    SizeMinBytes = "15M";
    SizeMaxBytes = "15M";
    PaddingMinBytes = "0";
  };
}
