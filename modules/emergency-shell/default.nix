{ config, lib, ... }:

let
  cfg = config.nixos-aarch64.emergencyShell;
in
{
  options.nixos-aarch64.emergencyShell.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable an emergency shell plus console logging for debugging early boot.
      Enables `boot.initrd.systemd.emergencyAccess` and adds systemd console
      kernel parameters. Requires `boot.initrd.systemd.enable` to take effect.
      Disabled by default; the project's repart image builds enable it.
    '';
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.systemd.emergencyAccess = true;

    boot.kernelParams = [
      "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1"
      "systemd.show_status=true"
      #"systemd.log_level=debug"
      "systemd.log_target=console"
      "systemd.journald.forward_to_console=1"
    ];
  };
}
