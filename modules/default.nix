{ self, inputs, ... }:

{
  flake.nixosModules = {
    cross = ./cross;
    sdimage = ./sdimage;
    repart-image = ./repart-image;
    repart-btrfs-esp = ./repart-btrfs-esp;
    rockchip-uboot-repart = ./rockchip-uboot-repart;

    bigtreetech-kernel = ./bigtreetech-kernel;
    fly-gemini-kernel = ./fly-gemini-kernel;
    fastrhino-r68s-kernel = ./fastrhino-r68s-kernel;
    orangepi-3b-kernel = ./orangepi-3b-kernel;
    panther-x2-kernel = ./panther-x2-kernel;
    radxa-e20c-kernel = ./radxa-e20c-kernel;

    apply-overlay = {
      imports = [ ./apply-overlay ];
      _module.args.self = self;
    };

    firstBoot = {
      nix.nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
      ];

      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };
      users.users.root.password = "nixos";
    };
  };
}
