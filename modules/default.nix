{ self, inputs, ... }:

{
  flake.nixosModules = {
    cross = ./cross;
    sdimage = ./sdimage;
    bigtreetech-kernel = {
      imports = [ ./bigtreetech-kernel ];
      _module.args.armbian = "${inputs.armbian}";
    };

    apply-overlay = {
      imports = [./apply-overlay];
      _module.args.self = self;
    };

    firstBoot = {
      services.openssh = {
        enable = true;
      };
      users.users.root.password = "";
    };
  };
}
