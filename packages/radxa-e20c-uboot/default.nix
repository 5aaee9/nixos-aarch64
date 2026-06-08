{ buildUBoot, rkbin }:

buildUBoot {
  defconfig = "radxa-e20c-rk3528_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];
  strictDeps = true;

  env = {
    BL31 = "${rkbin}/bin/rk35/rk3528_bl31_v1.20.elf";
    ROCKCHIP_TPL = "${rkbin}/bin/rk35/rk3528_ddr_1056MHz_v1.11.bin";
  };

  filesToInstall = [
    "idbloader.img"
    "u-boot.itb"
    "u-boot-rockchip.bin"
  ];
}
