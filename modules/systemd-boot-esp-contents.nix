{ config
, lib
, pkgs
}:

let
  loaderSource = "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
  bootFile = file:
    let
      fileString = toString file;
      fileName = builtins.baseNameOf fileString;
      storeDirName = builtins.elemAt (lib.splitString "/" (lib.removePrefix "/nix/store/" fileString)) 0;
    in
    builtins.unsafeDiscardStringContext
      "/EFI/nixos/${if fileName == storeDirName then "${fileName}.efi" else "${storeDirName}-${fileName}.efi"}";
  kernelFile = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
  initrdFile = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
  hasDeviceTree = config.hardware.deviceTree.enable && config.hardware.deviceTree.name != null;
  deviceTreeFile = "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
  loaderTimeout =
    if config.boot.loader.timeout == null then "menu-force" else toString config.boot.loader.timeout;
  loaderConfig = pkgs.writeText "loader.conf" ''
    timeout ${loaderTimeout}
    default nixos.conf
    ${lib.optionalString (!config.boot.loader.systemd-boot.editor) "editor 0"}
    console-mode ${config.boot.loader.systemd-boot.consoleMode}
  '';
  loaderEntry = pkgs.writeText "nixos.conf" ''
    title NixOS
    sort-key nixos
    version Initial image
    linux ${bootFile kernelFile}
    initrd ${bootFile initrdFile}
    options init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
    ${lib.optionalString hasDeviceTree "devicetree ${bootFile deviceTreeFile}"}
  '';
in
{
  inherit bootFile kernelFile initrdFile hasDeviceTree deviceTreeFile loaderConfig loaderEntry loaderSource;

  contents = {
    "/EFI/BOOT/BOOTAA64.EFI".source = loaderSource;
    "/EFI/systemd/systemd-bootaa64.efi".source = loaderSource;
    "/loader/loader.conf".source = loaderConfig;
    "/loader/entries/nixos.conf".source = loaderEntry;
    "${bootFile kernelFile}".source = kernelFile;
    "${bootFile initrdFile}".source = initrdFile;
  } // lib.optionalAttrs hasDeviceTree {
    "${bootFile deviceTreeFile}".source = deviceTreeFile;
  };

  populateFirmwareCommands = ''
    mkdir -p firmware/EFI/BOOT firmware/EFI/systemd firmware/EFI/nixos firmware/loader/entries
    install -m 0644 ${loaderSource} firmware/EFI/BOOT/BOOTAA64.EFI
    install -m 0644 ${loaderSource} firmware/EFI/systemd/systemd-bootaa64.efi
    install -m 0644 ${loaderConfig} firmware/loader/loader.conf
    install -m 0644 ${loaderEntry} firmware/loader/entries/nixos.conf
    install -m 0644 ${kernelFile} firmware${bootFile kernelFile}
    install -m 0644 ${initrdFile} firmware${bootFile initrdFile}
    ${lib.optionalString hasDeviceTree ''
      install -m 0644 ${deviceTreeFile} firmware${bootFile deviceTreeFile}
    ''}
  '';
}
