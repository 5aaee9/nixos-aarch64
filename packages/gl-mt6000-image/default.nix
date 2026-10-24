{
  lib,
  stdenvNoCC,
  config,
  pkgs,
  firmware,
}:

let
  kernel = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
  initrd = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
  dtb = "${config.hardware.deviceTree.package}/${config.hardware.deviceTree.name}";
  rootfs = config.system.build.toplevel;
  fit = "${config.system.build.mt6000Fit}";
in
stdenvNoCC.mkDerivation {
  pname = "nixos-gl-mt6000-image";
  version = config.system.nixos.version;

  nativeBuildInputs = [
    pkgs.dosfstools
    pkgs.e2fsprogs
    pkgs.gptfdisk
    pkgs.mtools
    pkgs.ubootTools
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    image=$out/sd-image/nixos-gl-mt6000.raw
    mkdir -p $out/sd-image
    truncate -s $((15269888 * 512)) "$image"

    sgdisk --clear \
      --new=1:8192:+512K --typecode=1:8300 --change-name=1:u-boot-env \
      --new=2:9216:+2M --typecode=2:8300 --change-name=2:factory \
      --new=3:13312:+2M --typecode=3:8300 --change-name=3:fip \
      --new=4:24576:+2M --typecode=4:8300 --change-name=4:cfg \
      --new=5:28672:+2M --typecode=5:8300 --change-name=5:log \
      --new=6:32768:+64M --typecode=6:8300 --change-name=6:kernel \
      --new=7:163840:0 --typecode=7:8300 --change-name=7:rootfs \
      "$image"

    test "$(stat -c %s ${fit})" -le $((64 * 1024 * 1024))
    dd if=${fit} of="$image" bs=512 seek=32768 conv=notrunc status=none
    cp ${fit} "$image.fit"

    rootfs_size=$((15269888 * 512 - 163840 * 512 - 34 * 512))
    truncate -s "$rootfs_size" "$image.rootfs"
    mkfs.ext4 -L rootfs -d ${rootfs} "$image.rootfs"
    dd if="$image.rootfs" of="$image" bs=512 seek=163840 conv=notrunc status=none

    dd if=${firmware}/share/gl-mt6000/bl31-uboot.fip of="$image" bs=512 seek=14336 conv=notrunc status=none

    sgdisk --verify "$image"
    runHook postInstall
  '';

  passthru = {
    inherit
      kernel
      initrd
      dtb
      fit
      ;
  };

  meta = {
    description = "Experimental GPT + U-Boot FIT image for GL.iNet GL-MT6000";
    platforms = lib.platforms.linux;
  };
}
