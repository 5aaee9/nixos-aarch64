{ self, inputs, ... }:

{
  flake.nixosModules = {
    cross = ./cross;
    sdimage = ./sdimage;

    bigtreetech-kernel = ./bigtreetech-kernel;
    fly-gemini-kernel = ./fly-gemini-kernel;

    apply-overlay = {
      imports = [ ./apply-overlay ];
      _module.args.self = self;
    };

    firstBoot = {
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };
      users.users.root.password = "";
    };
  };
}
