{
  description = "Personal nixos modules for aarch64 devices";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:5aaee9/nixpkgs";
    armbian = {
      url = "github:armbian/build";
      flake = false;
    };

    # bigtreetech-kernel = {
    #   url = "github:bigtreetech/linux/linux-6.1.y-cb1";
    #   flake = false;
    # };
  };

   outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./modules
        ./packages
        ./overlays
      ];
      systems = ["x86_64-linux" "aarch64-linux"];
    };
}
