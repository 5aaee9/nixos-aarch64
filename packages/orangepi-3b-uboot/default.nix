{ src, rkbin, buildUBoot, armTrustedFirmwareAllwinner }:

(buildUBoot {
  inherit src;
  version = "2017.09-rk3588";
  defconfig = "orangepi-3b-rk3566_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];

  filesToInstall = [ "spl/u-boot-spl.bin" "idbloader.img" "u-boot.itb" ];
  extraMakeFlags = [ "spl/u-boot-spl.bin" "u-boot.dtb" "u-boot.itb" ];

  BL31 = "${rkbin}/bin/rk35/rk3568_bl31_v1.43.elf";

  postBuild = ''
    ./tools/mkimage -n rk3568 -T rksd -d ${rkbin}/bin/rk35/rk3566_ddr_1056MHz_v1.18.bin:spl/u-boot-spl.bin idbloader.img
  '';
}).override ({
  patches = [ ];
  # drivers/mmc/rockchip_dw_mmc.c:45:22: error: the comparison will always evaluate as 'true' for the address of 'clk' will never be NULL [-Werror=address]
  env.NIX_CFLAGS_COMPILE = toString [ "-Wno-error=address" ];
})
