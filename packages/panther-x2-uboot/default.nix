{ src, rkbin, buildUBoot, armTrustedFirmwareAllwinner }:

(buildUBoot {
  defconfig = "panther-x2-rk3566_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];

  filesToInstall = [ "spl/u-boot-spl.bin" "idbloader.img" "u-boot.itb" ];

  ROCKCHIP_TPL = "${rkbin}/rk35/rk3566_ddr_1056MHz_v1.10.bin";
  BL31 = "${rkbin}/rk35/rk3568_bl31_v1.29.elf";

  # postBuild = ''
  #   ./tools/mkimage -n rk3568 -T rksd -d ${rkbin}/rk35/rk3566_ddr_1056MHz_v1.10.bin:spl/u-boot-spl.bin idbloader.img
  # '';
}).override ({
  # configs-rpi-allow-for-bigger-kernels.patch failed to apply
  patches = [
    ./add-trust-ini.patch
    ./316-rockchip-rk3566-Add-support-for-panther-x2.patch
  ];
  # drivers/mmc/rockchip_dw_mmc.c:45:22: error: the comparison will always evaluate as 'true' for the address of 'clk' will never be NULL [-Werror=address]
  # env.NIX_CFLAGS_COMPILE = toString [ "-Wno-error=address" ];
})
