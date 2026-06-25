{ rkbin, buildUBoot }:

buildUBoot {
  defconfig = "orangepi-3b-rk3566_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];

  env = {
    ROCKCHIP_TPL = "${rkbin}/bin/rk35/rk3566_ddr_1056MHz_v1.25.bin";
    BL31 = "${rkbin}/bin/rk35/rk3568_bl31_v1.46.elf";
  };

  filesToInstall = [
    "u-boot.itb"
    "idbloader.img"
    "u-boot-rockchip.bin"
    "u-boot-rockchip-spi.bin"
  ];
}
