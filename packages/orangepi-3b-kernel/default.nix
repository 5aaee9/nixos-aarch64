{ orangepiSrc, lib, linuxManualConfig, stdenv, ubootTools, fetchFromGitHub, kernelPatches, ... }:

with lib;
let
  src = fetchFromGitHub {
    owner = "orangepi-xunlong";
    repo = "linux-orangepi";
    rev = "3c0ea83c49a1e4959161c9953f142ac91ea8ddd8";
    sha256 = "sha256-WwO+/Aug8eCNiJ5ju5wFidEotShjXA416x9PCY96Cjw=";
  };
in
(linuxManualConfig {
  inherit lib stdenv src;

  kernelPatches = kernelPatches ++ [
    {
      name = "fix-uwe5622-build";
      patch = ./0001-fix-uwe5622-failed-build.patch;
    }
    {
      name = "fix-rtl8189es";
      patch = ./0002-fix-rtl-and-rockchip-wlan.patch;
    }
  ];

  version = "5.10.160-orangepi3b";

  modDirVersion = "5.10.160";
  extraMeta.branch = "orangepi3b";

  configfile = ./linux-rk3566-orange-pi-3b.config;
  allowImportFromDerivation = true;
}).overrideAttrs (old: {
  # Base path too long (/boot/extlinux/../nixos/sxb3wlbx3qamav3vpy9s90kmr60pp5ij-linux-aarch64-unknown-linux-gnu-5.10.160-orangepi3b-dtbs/rockchip/rk3566-orangepi-3b.dtb)
  name = "k"; # dodge uboot length limits
  nativeBuildInputs = old.nativeBuildInputs ++ [ ubootTools ];
})
