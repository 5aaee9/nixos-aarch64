{ self, inputs, ... }:

{
  flake.nixosModules = {
    cross = ./cross;
    sdimage = ./sdimage;

    bigtreetech-kernel = ./bigtreetech-kernel;
    fly-gemini-kernel = ./fly-gemini-kernel;
    orangepi-3b-kernel = ./orangepi-3b-kernel;

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
      users.users.root.password = "";
    };
  };
}
