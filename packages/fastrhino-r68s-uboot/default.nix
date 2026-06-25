{ buildUBoot, rkbin }:

buildUBoot {
  defconfig = "generic-rk3568_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];

  env = {
    BL31 = rkbin.BL31_RK3568;
    ROCKCHIP_TPL = rkbin.TPL_RK3568;
  };

  filesToInstall = [
    "idbloader.img"
    "u-boot.itb"
  ];

  extraPatches = [ ./use-r68s-device-tree.patch ];
}
