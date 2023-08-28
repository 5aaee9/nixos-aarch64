{
  description = "Personal nixos modules for aarch64 devices";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:5aaee9/nixpkgs";
    armbian = {
      url = "github:armbian/build";
      flake = false;
    };

    bigtreetech-kernel = {
      url = "github:bigtreetech/linux/linux-6.1.y-cb1";
      flake = false;
    };

    devenv.url = "github:cachix/devenv";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";

    orangepi-uboot = {
      url = "github:orangepi-xunlong/u-boot-orangepi/v2017.09-rk3588";
      flake = false;
    };

    orangepi-kernel = {
      url = "github:orangepi-xunlong/linux-orangepi/orange-pi-5.10-rk35xx";
      flake = false;
    };

    rkbin = {
      url = "github:rockchip-linux/rkbin";
      flake = false;
    };
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules
        ./packages
        ./overlays
        inputs.devenv.flakeModule
      ];

      systems = [ "x86_64-linux" "aarch64-linux" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        devenv.shells.default = {
          name = "nixos-aarch64";

          packages = with pkgs; [
            lefthook
            nixpkgs-fmt
          ];

          enterShell = ''
            lefthook install
          '';
        };
      };
    };
}
