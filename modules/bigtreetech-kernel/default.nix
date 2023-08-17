{ config, lib, pkgs, armbian, ... }:

with lib.strings;
with builtins;

let
  filterFile = file: (hasPrefix "-" file) || (hasPrefix "#" file) || (file == "");
  readPatchList = file: (filter (it: !(filterFile it)) (map (it: removePrefix "\t" it) (splitString "\n" (fileContents file))));

  applyPatches = readPatchList "${armbian}/patch/kernel/archive/sunxi-6.1/series.conf";

  patches = map (it: {
    name = it;
    patch = "${armbian}/patch/kernel/archive/sunxi-6.1/${it}";
  }) applyPatches;
in
{
  boot.kernelPackages = pkgs.linuxPackages_6_1;
  hardware.deviceTree.enable = true;
  boot.consoleLogLevel = lib.mkDefault 7;
  boot.kernelParams = [ "console=ttyS0,115200" "consoleblank=0" ];

  boot.initrd.availableKernelModules = lib.mkForce [
    "8189fs"

    "ext4" "sunxi-mmc" "sdhci_pci"
    "axp20x-ac-power" "axp20x-battery"
    "sd_mod" "sr_mod" "mmc_block"
    "uhci_hcd" "ehci_hcd" "ehci_pci"
    "ohci_hcd" "ohci_pci" "xhci_hcd" "xhci_pci"
  ];

  boot.kernelPatches = [
    {
      name = "BigTreeTech-Pi-Extra";
      patch = null;
      extraConfig = ''
        DRM_SUN8I_MIXER n
        ARCH_RENESAS n

        ETHERNET y
        NET_VENDOR_ALLWINNER y
        SUNXI_GMAC y
        SUNXI_EXT_PHY y

        ARCH_SUNXI y
        MMC y
        PWRSEQ_EMMC y
        MMC_BLOCK y
        MMC_BLOCK_MINORS 32
        MMC_ARMMMCI y
        MMC_STM32_SDMMC y
        MMC_SDHCI y
        MMC_SDHCI_IO_ACCESSORS y
        MMC_SDHCI_PLTFM y
        MMC_SDHCI_OF_ASPEED m
        MMC_SDHCI_MILBEAUT m
        MMC_SPI y
        MMC_DW y
        MMC_DW_PLTFM y
        MMC_DW_BLUEFIELD m
        MMC_DW_EXYNOS y
        MMC_DW_HI3798CV200 m
        MMC_DW_K3 y
        MMC_SUNXI y
        MMC_CQHCI m
        MMC_HSQ m
        MMC_SDHCI_AM654 m
      '';
    }
  ] ++ patches;

  hardware.deviceTree.name = "allwinner/sun50i-h616-bigtreetech-cb1-sd.dtb";

}
