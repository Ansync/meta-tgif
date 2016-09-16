#
#@DESCRIPTION: Linux for Variscite i.MX6Q/Dl/Solo VAR-SOM-MX6
#@MAINTAINER: Ron Donio <ron.d@variscite.com>
#
# http://www.variscite.com
# support@variscite.com
#
require recipes-kernel/linux/linux-imx.inc
require recipes-kernel/linux/linux-dtb.inc

DEPENDS += "lzop-native bc-native"

SRCBRANCH = "master"
SRCREV = "87cdb356eff19dd05625321022643bb98a4a9821"
KERNEL_SRC ?= "git://github.com/Ansync/kernel-tgif.git;protocol=git"
SRC_URI = "${KERNEL_SRC};branch=${SRCBRANCH}"

FSL_KERNEL_DEFCONFIG = "imx_v7_var_defconfig"

KERNEL_IMAGETYPE = "uImage"

KERNEL_EXTRA_ARGS += "LOADADDR=${UBOOT_ENTRYPOINT}"

do_configure_prepend() {
   # copy latest defconfig for imx_v7_var_defoonfig to use
   cp ${S}/arch/arm/configs/imx_v7_var_defconfig ${B}/.config
   cp ${S}/arch/arm/configs/imx_v7_var_defconfig ${B}/../defconfig
}


# Copy the config file required by ti-compat-wirless-wl18xx
do_deploy_append () {
   cp ${S}/arch/arm/configs/imx_v7_var_defconfig ${S}/.config
}


COMPATIBLE_MACHINE = "(var-som-mx6)"

DEFAULT_PREFERENCE = "1"

