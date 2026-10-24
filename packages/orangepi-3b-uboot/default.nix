{ fetchFromGitHub, buildUBoot }:

let
  rkbin = fetchFromGitHub {
    owner = "rockchip-linux";
    repo = "rkbin";
    rev = "ecb4fcbe954edf38b3ae037d5de6d9f5bccf81f4";
    hash = "sha256-U8d2cH6/TSXfBnLhh141A9wP/t6prFgwYMvwgXBf4vc=";
  };
in
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
