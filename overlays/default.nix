{ inputs, ... }: {
  imports = [ inputs.flake-parts.flakeModules.easyOverlay ];

  perSystem = { config, ... }: {
    overlayAttrs = {
      linux-bigtreetech = config.packages.linux-bigtreetech;
      linux-orangepi-3b = config.packages.linux-orangepi-3b;
      fastrhino-r68s-uboot = config.packages.fastrhino-r68s-uboot;
      radxa-e20c-uboot = config.packages.radxa-e20c-uboot;
    };
  };
}
