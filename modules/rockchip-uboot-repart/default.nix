{ lib, ... }:

{
  imports = [ ../repart-options ];

  nixos-aarch64.repartImage.rockchipUboot.enable = lib.mkDefault true;
}
