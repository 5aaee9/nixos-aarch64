{ config
, lib
, pkgs
, modulesPath
, ...
}: {
  options.sdImage.extraPostbuild = lib.mkOption {
    type = with lib.types; str;
    default = "";
  };

  imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];

  config = {
    boot.loader.grub.enable = false;
    boot.loader.generic-extlinux-compatible.enable = true;
    networking.firewall.enable = false;

    boot.initrd.systemd = {
      enable = true;
      emergencyAccess = true;
      initrdBin = with pkgs; [ gnugrep strace ]; # for debugging only
    };

    sdImage = {
      firmwareSize = lib.mkDefault 1;
      firmwarePartitionOffset = lib.mkDefault 8;

      populateFirmwareCommands = lib.mkDefault "";

      postBuildCommands = ''
        ${config.sdImage.extraPostbuild}
      '';

      populateRootCommands = ''
        mkdir -p ./files/boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
      '';
      compressImage = lib.mkDefault true;
    };
  };
}
