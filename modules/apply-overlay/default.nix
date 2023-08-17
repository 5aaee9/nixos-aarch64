{
  config,
  lib,
  self,
  ...
}: let
  inherit (config.nixpkgs) localSystem;
  selectedPlatform = lib.systems.elaborate "aarch64-linux";
  isCross = localSystem != selectedPlatform.system;
  dynamicOverlay =
    if isCross
    then
      (prev: super:
        with (self.packages.${localSystem.system}); {
          inherit linux-bigtreetech;
        })
    else self.overlays.default;
in {
  nixpkgs.overlays = [
    dynamicOverlay
  ];
}
