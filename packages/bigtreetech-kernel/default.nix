{ bigtreetechSrc, lib, linuxManualConfig, stdenv, ubootTools, ... }:

with lib;

(linuxManualConfig {

  src = bigtreetechSrc;
  inherit lib stdenv;

  version = "6.1.43-bigtreetech";

  modDirVersion = "6.1.43";
  extraMeta.branch = "bigtreetech";

  configfile = ./linux-sun50iw9-btt-legacy.config;
  allowImportFromDerivation = true;
}).overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ ubootTools ];
})
