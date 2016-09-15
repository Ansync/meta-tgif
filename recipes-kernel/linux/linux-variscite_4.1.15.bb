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

SRC_URI = "git://github.com/Ansync/kernel-tgif"
SRCREV = "043b7a4d40a6db7cb1243550d3debc8c8bee6320"

# SRCBRANCH = "imx-rel_imx_4.1.15_1.1.0_ga-VAR01-beta"
# LOCALVERSION = "-6QP"
# SRCREV = "29913ef00be72bb227f10d325b652c1dabc41d28"
# KERNEL_SRC ?= "git://github.com/Ansync/kernel-tgif.git;protocol=git"
# SRC_URI = "${KERNEL_SRC};branch=${SRCBRANCH}"
# LOCALVERSION = "-1.1.0"

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

