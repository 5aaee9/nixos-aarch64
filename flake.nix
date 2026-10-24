{
  description = "Personal nixos modules for aarch64 devices";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs";
    armbian = {
      url = "github:armbian/build";
      flake = false;
    };

    bigtreetech-kernel = {
      url = "github:bigtreetech/linux/linux-6.1.y-cb1";
      flake = false;
    };

    devenv.url = "github:cachix/devenv";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    orangepi-uboot = {
      url = "github:orangepi-xunlong/u-boot-orangepi/v2017.09-rk3588";
      flake = false;
    };

    radxa-uboot = {
      url = "github:radxa/u-boot/stable-4.19-rock3";
      flake = false;
    };

    # orangepi-kernel = {
    #   url = "github:orangepi-xunlong/linux-orangepi/orange-pi-5.10-rk35xx";
    #   flake = false;
    # };

    rkbin = {
      url = "github:rockchip-linux/rkbin";
      flake = false;
    };

    rkbin-armbian = {
      url = "github:armbian/rkbin";
      flake = false;
    };

    mt798x-boot = {
      url = "github:gl-inet/mt798x-boot";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./modules
        ./packages
        ./overlays
        inputs.devenv.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt = {
              enable = true;
              strict = true;
            };
            programs.prettier.enable = true;
            settings.formatter.prettier.includes = [ "*.md" ];
          };

          devenv.shells.default = {
            name = "nixos-aarch64";
            devenv.root = toString ./.;

            packages = [
              pkgs.lefthook
              config.treefmt.build.wrapper
            ];

            enterShell = ''
              lefthook install
            '';
          };
        };
    };
}
