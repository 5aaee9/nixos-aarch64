{
  fetchFromGitHub,
  lib,
  linuxManualConfig,
  stdenv,
  ubootTools,
  ...
}:

with lib;

(linuxManualConfig {

  src = fetchFromGitHub {
    owner = "bigtreetech";
    repo = "linux";
    rev = "f33ca29a323571460e56167c986a52c19a3f1e01";
    hash = "sha256-yAL6BXPLCW1cdDg9M/GKWbXF17Q07DOegFYAf0w6vmk=";
  };
  inherit lib stdenv;

  version = "6.1.43-bigtreetech";

  modDirVersion = "6.1.43";
  extraMeta.branch = "bigtreetech";

  configfile = ./linux-sun50iw9-btt-legacy.config;
  allowImportFromDerivation = true;
}).overrideAttrs
  (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ ubootTools ];
  })
