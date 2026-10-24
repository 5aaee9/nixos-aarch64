{
  stdenv,
  lib,
  fetchFromGitHub,
  bc,
  bison,
  dtc,
  flex,
  openssl,
  python3,
  which,
  gcc,
}:

stdenv.mkDerivation {
  pname = "gl-mt6000-firmware";
  version = "2022-06-06";
  src = fetchFromGitHub {
    owner = "gl-inet";
    repo = "mt798x-boot";
    rev = "8f73dd1a66e2a9037e48ca7df6c5b14a48672a6e";
    hash = "sha256-eKHjZStZT0G6mPlaQ854DmgwG8b8HhowtVJ+28iIPCQ=";
  };

  nativeBuildInputs = [
    bison
    bc
    dtc
    flex
    openssl
    python3
    which
  ];
  depsBuildBuild = [ gcc ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    export CROSS_COMPILE="${stdenv.hostPlatform.config}-"
    export ARCH=arm

    make -C uboot-mtk-20220606 gl_mt6000_defconfig
    sed -i '/^CONFIG_WEBUI_FAILSAFE=y$/c\\# CONFIG_WEBUI_FAILSAFE is not set' \
      uboot-mtk-20220606/.config
    make -C uboot-mtk-20220606 olddefconfig
    make -C uboot-mtk-20220606 -j$NIX_BUILD_CORES

    cp uboot-mtk-20220606/u-boot.bin atf-20220606-637ba581b/
    make -C atf-20220606-637ba581b gl_mt6000_defconfig
    sed -i '/TF_LDFLAGS.*--fatal-warnings/d' atf-20220606-637ba581b/Makefile
    sed -i 's|^CONFIG_CROSS_COMPILER=.*|CONFIG_CROSS_COMPILER="'$CROSS_COMPILE'"|' \
      atf-20220606-637ba581b/.config
    make -C atf-20220606-637ba581b -j1

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm0644 atf-20220606-637ba581b/build/mt7986/release/bl2.img \
      $out/share/gl-mt6000/preloader.bin
    install -Dm0644 atf-20220606-637ba581b/build/mt7986/release/fip.bin \
      $out/share/gl-mt6000/bl31-uboot.fip
    runHook postInstall
  '';

  meta = {
    description = "BL2 and BL31/U-Boot firmware for the GL.iNet GL-MT6000 eMMC boot chain";
    homepage = "https://github.com/gl-inet/mt798x-boot";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
