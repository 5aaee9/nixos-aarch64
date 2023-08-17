{inputs, ...}: {
  imports = [
    inputs.flake-parts.flakeModules.easyOverlay
  ];

  perSystem = {config, ...}: {
    overlayAttrs = {
      linux-bigtreetech = config.packages.linux-bigtreetech;
    };
  };
}
