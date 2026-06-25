{
  config,
  lib,
  self,
  ...
}:
let
  inherit (config.nixpkgs) localSystem;
  selectedPlatform = lib.systems.elaborate "aarch64-linux";
  isCross = localSystem != selectedPlatform.system;
  dynamicOverlay =
    if isCross then
      (
        prev: super: with (self.packages.${localSystem.system}); {
          inherit
            fastrhino-r68s-uboot
            linux-bigtreetech
            linux-orangepi-3b
            radxa-e20c-uboot
            uwe5622-firmware
            ;
        }
      )
    else
      self.overlays.default;
in
{
  nixpkgs.overlays = [ dynamicOverlay ];
}
