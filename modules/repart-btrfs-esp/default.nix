{ lib, ... }:

{
  imports = [ ../repart-options ];

  nixos-aarch64.repartImage.btrfsEsp.enable = lib.mkDefault true;
}
