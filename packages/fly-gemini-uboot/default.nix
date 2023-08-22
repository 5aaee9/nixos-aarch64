{ buildUBoot, armTrustedFirmwareAllwinner }:

buildUBoot {
  defconfig = "fly_gemini_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];
  extraPatches = [
    ./u-boot-arm-arch-dts-Makefile.patch
    ./u-boot-configs-fly_gemini_defconfig.patch
    ./u-boot-dts-sun50i-h5-fly-gemini.patch
  ];
  SCP = "/dev/null";
  BL31 = "${armTrustedFirmwareAllwinner}/bl31.bin";
  filesToInstall = [ "u-boot-sunxi-with-spl.bin" ];
}
