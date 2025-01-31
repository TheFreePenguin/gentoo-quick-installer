#!/bin/bash

##
# GENTOO QUICK INSTALLER
#
# Read more: http://www.artembutusov.com/gentoo-linux-quick-installer-script/
#
# Usage:
#
# export OPTION1=VALUE1
# export OPTION2=VALUE2
# ./gentoo-quick-installer.sh
#
# Options:
#
# USE_LIVECD_KERNEL - 1 to use livecd kernel (saves time) or 0 to build kernel (takes time)
# SSH_PUBLIC_KEY - ssh public key, pass contents of `cat ~/.ssh/id_rsa.pub` for example
# ROOT_PASSWORD - root password, only SSH key-based authentication will work if not set
##

echo 'Make sure you have wget installed. If you do not have wget installed, press ⎈C and install wget.'
read
# ⎈⌥⌦

# Sets up EFI
echo 'Is this an EFI computer? [Y/n]'
read
if [ $REPLY = n ]
then
EFI=false
else
EFI=true
fi

echo 'Which disk do you want to install Gentoo onto?'
read TARGET_DISK

echo 'Are you installing Gentoo on an NVMe drive? [Y/n]'
read
if [ $REPLY = n ]
then
NVME=''
else
NVME='p'
fi

echo 'You do not need to format the partitions. The installer will do that for you. Press ENTER to continue'
read

cfdisk $TARGET_DISK

[ EFI = true ] && echo 'What partition do you want to use as your ESP? (Only enter the number)' && read EFI_PART
echo 'What partition do you want to use as your boot partition? (Only enter the number)'
read BOOT_PART
echo 'What partition do you want to use as your root partition? (Only enter the number)'
read ROOT_PART
echo 'What partition do you want to use as your swap partition? (Only enter the number)'
read SWAP_PART
set -e



GENTOO_MIRROR="http://distfiles.gentoo.org"

GENTOO_ARCH="amd64"
GENTOO_STAGE3="amd64"


TARGET_BOOT_SIZE=100M
TARGET_SWAP_SIZE=1G

GRUB_PLATFORMS=pc

USE_LIVECD_KERNEL=${USE_LIVECD_KERNEL:-1}

ROOT_PASSWORD=root

echo "### Checking configuration..."

if [ -z "$SSH_PUBLIC_KEY" ] && [ -z "$ROOT_PASSWORD" ]; then
    echo "SSH_PUBLIC_KEY or ROOT_PASSWORD must be set to continue"
    exit 1
fi

echo "### Setting time..."

ntpd -gq

echo "### Formatting partitions..."

yes | mkfs.ext4 ${TARGET_DISK}${NVME}${BOOT_PART}
yes | mkswap ${TARGET_DISK}${NVME}${SWAP_PART}
yes | mkfs.ext4 ${TARGET_DISK}${NVME}${ROOT_PART}

echo "### Labeling partitions..."

[ EFI = true ] && e2label ${TARGET_DISK}${NVME}${EFI_PART} efi
e2label ${TARGET_DISK}${NVME}${BOOT_PART} boot
swaplabel ${TARGET_DISK}${NVME}${SWAP_PART} -L swap
e2label ${TARGET_DISK}${NVME}${ROOT_PART} root

echo "### Mounting partitions..."

swapon ${TARGET_DISK}${NVME}${SWAP_PART}

mkdir -p /mnt/gentoo
mount ${TARGET_DISK}${NVME}${ROOT_PART} /mnt/gentoo

mkdir -p /mnt/gentoo/boot
mount ${TARGET_DISK}${NVME}${BOOT_PART} /mnt/gentoo/boot

[ EFI = true ] && mkdir -p /mnt/gentoo/boot/efi && mount ${TARGET_DISK}${NVME}${EFI_PART} /mnt/gentoo/boot/efi


echo "### Setting work directory..."

cd /mnt/gentoo

echo "### Installing stage3..."

STAGE3_PATH_URL="$GENTOO_MIRROR/releases/$GENTOO_ARCH/autobuilds/latest-stage3-$GENTOO_STAGE3.txt"
STAGE3_PATH=$(curl -s "$STAGE3_PATH_URL" | grep -v "^#" | cut -d" " -f1)
STAGE3_URL="$GENTOO_MIRROR/releases/$GENTOO_ARCH/autobuilds/$STAGE3_PATH"

wget "$STAGE3_URL"

tar xvpf "$(basename "$STAGE3_URL")" --xattrs-include='*.*' --numeric-owner

rm -fv "$(basename "$STAGE3_URL")"

echo "### Making kernel dir..."
mkdir -p /etc/kernels
cp /boot/*linu* /etc/kernels

echo "### Installing kernel configuration..."

mkdir -p /mnt/gentoo/etc/kernels
cp -v /etc/kernels/* /mnt/gentoo/etc/kernels

echo "### Copying network options..."

cp -v /etc/resolv.conf /mnt/gentoo/etc/

echo "### Configuring fstab..."

cat >> /mnt/gentoo/etc/fstab << END
# added by gentoo installer
LABEL=efi /boot/efi vfat defaults 0 1
LABEL=boot /boot ext4 noauto,noatime 1 2
LABEL=swap none  swap sw             0 0
LABEL=root /     ext4 noatime        0 1
END

echo "### Mounting proc/sys/dev..."

mount -t proc none /mnt/gentoo/proc
mount -t sysfs none /mnt/gentoo/sys
mount -o bind /dev /mnt/gentoo/dev
mount -o bind /dev/pts /mnt/gentoo/dev/pts
mount -o bind /dev/shm /mnt/gentoo/dev/shm

echo "### Changing root..."

chroot /mnt/gentoo ./post-chroot.sh

