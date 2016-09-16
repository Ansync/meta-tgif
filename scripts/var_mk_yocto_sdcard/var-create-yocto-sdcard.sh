#!/bin/bash
set -e

# Sizes are in MiB
BOOTLOAD_RESERVE_SIZE=4
BOOT_ROM_SIZE=8
DEFAULT_ROOTFS_SIZE=3700

AUTO_FILL_SD=0
SPARE_SIZE=4

YOCTO_ROOT=~/jethro
YOCTO_BUILD=${YOCTO_ROOT}/build

YOCTO_IMGS_PATH=${YOCTO_BUILD}/tmp/deploy/images/var-som-mx6
YOCTO_SCRIPTS_PATH=${YOCTO_ROOT}/sources/meta-tgif/scripts/var_mk_yocto_sdcard/variscite_scripts

TEMP_DIR=./var_tmp
P1_MOUNT_DIR=${TEMP_DIR}/BOOT-VAR-SOM
P2_MOUNT_DIR=${TEMP_DIR}/rootfs

echo "================================================"
echo "= Variscite build recovery SD-card V50 utility ="
echo "================================================"

help() {

bn=`basename $0`
cat << EOF
Usage: $bn <options> device_node

options:
  -h		Display this help message
  -s		Only show partition sizes to be written, without actually write them
  -a		Automatically set the rootfs partition size to fill the SD-card (leaving spare ${SPARE_SIZE}MiB)

EOF

}

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run with super-user privileges" 
	exit 1
fi


# Parse command line
moreoptions=1
node="na"
cal_only=0

while [ "$moreoptions" = 1 -a $# -gt 0 ]; do
	case $1 in
	    -h) help; exit 3 ;;
	    -s) cal_only=1 ;;
	    -a) AUTO_FILL_SD=1 ;;
	    *)  moreoptions=0; node=$1 ;;
	esac
	[ "$moreoptions" = 0 ] && [ $# -gt 1 ] && help && exit 1
	[ "$moreoptions" = 1 ] && shift
done

if [ ! -e ${node} ]; then
	help
	exit 1
fi

part=""
if [ `echo ${node} | grep -c mmcblk` -ne 0 ]; then
	part="p"
fi

echo "Device:  ${node}"
echo "================================================"
read -p "Press Enter to continue"

for ((i=0; i<10; i++))
do
	if [ `mount | grep -c ${node}${part}$i` -ne 0 ]; then
		umount ${node}${part}$i
	fi
done

# Call sfdisk to get total card size
if [ "${AUTO_FILL_SD}" -eq "1" ]; then
	TOTAL_SIZE=`sfdisk -s ${node}`
	TOTAL_SIZE=`expr ${TOTAL_SIZE} / 1024`
	ROOTFS_SIZE=`expr ${TOTAL_SIZE} - ${BOOTLOAD_RESERVE_SIZE} - ${BOOT_ROM_SIZE} - ${SPARE_SIZE}`
else
	ROOTFS_SIZE=${DEFAULT_ROOTFS_SIZE}
fi

if [ "${cal_only}" -eq "1" ]; then
cat << EOF
BOOTLOADER (No Partition) : ${BOOTLOAD_RESERVE_SIZE}MiB 
BOOT                      : ${BOOT_ROM_SIZE}MiB
ROOT-FS                   : ${ROOTFS_SIZE}MiB
EOF
exit 3
fi

function format_yocto
{
	echo "Formating Yocto partitions"
	mkfs.vfat ${node}${part}1 -n BOOT-VARSOM
	mkfs.ext4 ${node}${part}2 -L rootfs
}

function flash_u-boot
{
	echo "Flashing U-Boot"
	dd if=${YOCTO_IMGS_PATH}/SPL-sd of=${node} bs=1K seek=1; sync
	dd if=${YOCTO_IMGS_PATH}/u-boot-sd-2015.04-r0.img of=${node} bs=1K seek=69; sync
}

function flash_yocto
{
	echo "Flashing Yocto Boot partition"    
	cp ${YOCTO_IMGS_PATH}/uImage-imx6q-var-som.dtb 			${P1_MOUNT_DIR}/imx6q-var-som.dtb
	cp ${YOCTO_IMGS_PATH}/uImage-imx6dl-var-som.dtb 		${P1_MOUNT_DIR}/imx6dl-var-som.dtb
	cp ${YOCTO_IMGS_PATH}/uImage-imx6q-var-som-vsc.dtb 		${P1_MOUNT_DIR}/imx6q-var-som-vsc.dtb
	cp ${YOCTO_IMGS_PATH}/uImage-imx6dl-var-som-solo.dtb 		${P1_MOUNT_DIR}/imx6dl-var-som-solo.dtb
	cp ${YOCTO_IMGS_PATH}/uImage-imx6dl-var-som-solo-vsc.dtb 	${P1_MOUNT_DIR}/imx6dl-var-som-solo-vsc.dtb
	cp ${YOCTO_IMGS_PATH}/uImage-imx6q-var-dart.dtb 		${P1_MOUNT_DIR}/imx6q-var-dart.dtb
	cp ${YOCTO_IMGS_PATH}/uImage 					${P1_MOUNT_DIR}/uImage
	sync

	echo "Flashing Yocto Root File System"    
	pv ${YOCTO_IMGS_PATH}/fsl-image-gui-var-som-mx6.tar.bz2 | tar -xj -C ${P2_MOUNT_DIR}/
}

function copy_yocto
{
	mkdir -p ${P2_MOUNT_DIR}/opt/images/Yocto

	echo "Copying Yocto to /opt/images/"
	cp ${YOCTO_IMGS_PATH}/uImage 					${P2_MOUNT_DIR}/opt/images/Yocto
	pv ${YOCTO_IMGS_PATH}/fsl-image-gui-var-som-mx6.tar.bz2 >	${P2_MOUNT_DIR}/opt/images/Yocto/rootfs.tar.bz2
	pv ${YOCTO_IMGS_PATH}/fsl-image-gui-var-som-mx6.ubi >	${P2_MOUNT_DIR}/opt/images/Yocto/rootfs.ubi.img

	cp ${YOCTO_IMGS_PATH}/uImage-imx6dl-var-som-solo.dtb 		${P2_MOUNT_DIR}/opt/images/Yocto/
	cp ${YOCTO_IMGS_PATH}/uImage-imx6dl-var-som-solo-vsc.dtb 	${P2_MOUNT_DIR}/opt/images/Yocto/
	cp ${YOCTO_IMGS_PATH}/uImage-imx6dl-var-som.dtb 		${P2_MOUNT_DIR}/opt/images/Yocto/
	cp ${YOCTO_IMGS_PATH}/uImage-imx6q-var-som.dtb 			${P2_MOUNT_DIR}/opt/images/Yocto/
	cp ${YOCTO_IMGS_PATH}/uImage-imx6q-var-som-vsc.dtb 		${P2_MOUNT_DIR}/opt/images/Yocto/
	cp ${YOCTO_IMGS_PATH}/uImage-imx6q-var-dart.dtb 		${P2_MOUNT_DIR}/opt/images/Yocto/
	echo "Copying NAND U-Boot to /opt/images/Yocto"
	cp ${YOCTO_IMGS_PATH}/SPL-nand					${P2_MOUNT_DIR}/opt/images/Yocto/SPL
	cp ${YOCTO_IMGS_PATH}/u-boot-nand-2015.04-r0.img		${P2_MOUNT_DIR}/opt/images/Yocto/u-boot.img
	echo "Copying MMC U-Boot to /opt/images/Yocto"
	cp ${YOCTO_IMGS_PATH}/SPL-sd					${P2_MOUNT_DIR}/opt/images/Yocto/SPL.mmc
	cp ${YOCTO_IMGS_PATH}/u-boot-sd-2015.04-r0.img			${P2_MOUNT_DIR}/opt/images/Yocto/u-boot.img.mmc
}

function copy_scripts
{
	echo "Copying scripts"
	cp ${YOCTO_SCRIPTS_PATH}/nand-recovery.sh 	${P2_MOUNT_DIR}/sbin/
	cp ${YOCTO_SCRIPTS_PATH}/yocto-nand.sh 		${P2_MOUNT_DIR}/sbin/
	cp ${YOCTO_SCRIPTS_PATH}/yocto-emmc.sh 		${P2_MOUNT_DIR}/sbin/
	cp ${YOCTO_SCRIPTS_PATH}/yocto-dart.sh 		${P2_MOUNT_DIR}/sbin/

	cp ${YOCTO_SCRIPTS_PATH}/mkmmc_yocto.sh 	${P2_MOUNT_DIR}/sbin/

	echo "Copying desktop icons"
	cp ${YOCTO_SCRIPTS_PATH}/*.desktop 		${P2_MOUNT_DIR}/usr/share/applications/ 
	cp ${YOCTO_SCRIPTS_PATH}/terminal* 		${P2_MOUNT_DIR}/usr/bin/
}

function ceildiv
{
    local num=$1
    local div=$2
    echo $(( (num + div - 1) / div ))
}

# Delete the partitions
for ((i=0; i<10; i++))
do
	if [ `ls ${node}${part}$i 2> /dev/null | grep -c ${node}${part}$i` -ne 0 ]; then
		dd if=/dev/zero of=${node}${part}$i bs=512 count=1024
	fi
done
sync

((echo d; echo 1; echo d; echo 2; echo d; echo 3; echo d; echo w) | fdisk ${node} &> /dev/null) || true
sync

dd if=/dev/zero of=${node} bs=512 count=1024
sync

# Create partitions
BLOCK=`echo ${node} | cut -d "/" -f 3`
SECT_SIZE_BYTES=`cat /sys/block/${BLOCK}/queue/physical_block_size`

BOOTLOAD_RESERVE_SIZE_BYTES=$((BOOTLOAD_RESERVE_SIZE * 1024 * 1024))
BOOT_ROM_SIZE_BYTES=$((BOOT_ROM_SIZE * 1024 * 1024))
ROOTFS_SIZE_BYTES=$((ROOTFS_SIZE * 1024 * 1024))

PART1_START=`ceildiv ${BOOTLOAD_RESERVE_SIZE_BYTES} ${SECT_SIZE_BYTES}`
PART1_SIZE=`ceildiv ${BOOT_ROM_SIZE_BYTES} ${SECT_SIZE_BYTES}`
PART2_START=$((PART1_START + PART1_SIZE))
PART2_SIZE=$((ROOTFS_SIZE_BYTES / SECT_SIZE_BYTES)) 

sfdisk --force -uS ${node} << EOF
${PART1_START},${PART1_SIZE},c
${PART2_START},${PART2_SIZE},83
EOF

echo

# Format the partitions
format_yocto

flash_u-boot

# Mount the partitions
mkdir -p ${P1_MOUNT_DIR}
mkdir -p ${P2_MOUNT_DIR}
sync
mount ${node}${part}1  ${P1_MOUNT_DIR}
mount ${node}${part}2  ${P2_MOUNT_DIR}

flash_yocto
copy_yocto
copy_scripts

echo "Syncing"
sync | pv -t
umount ${P1_MOUNT_DIR}
umount ${P2_MOUNT_DIR}
rm -rf ${TEMP_DIR}
echo "Done"
exit 0
