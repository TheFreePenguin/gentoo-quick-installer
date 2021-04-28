#!/bin/bash
set -e
echo "### Upading configuration..."
env-update
source /etc/profile
echo "### Installing portage..."
mkdir -p /etc/portage/repos.conf
cp -f /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf
emerge-webrsync
echo "### Installing kernel sources..."
emerge sys-kernel/gentoo-sources
if [ "$USE_LIVECD_KERNEL" = 0 ]; then
    echo "### Installing kernel..."
    echo "sys-kernel/genkernel -firmware" > /etc/portage/package.use/genkernel
    echo "sys-apps/util-linux static-libs" >> /etc/portage/package.use/genkernel
    emerge sys-kernel/genkernel
    genkernel all --kernel-config=$(find /etc/kernels -type f -iname 'kernel-config-*' | head -n 1)
fi
echo "### Installing bootloader..."
emerge grub
cat >> /etc/portage/make.conf << IEND
# added by gentoo installer
GRUB_PLATFORMS="$GRUB_PLATFORMS"
IEND
cat >> /etc/default/grub << IEND
# added by gentoo installer
GRUB_CMDLINE_LINUX="net.ifnames=0"
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
IEND
grub-install ${TARGET_DISK}
grub-mkconfig -o /boot/grub/grub.cfg
echo "### Configuring network..."
ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default
if [ -z "$ROOT_PASSWORD" ]; then
    echo "### Removing root password..."
    passwd -d -l root
else
    echo "### Configuring root password..."
    echo "root:$ROOT_PASSWORD" | chpasswd
fi
if [ -n "$SSH_PUBLIC_KEY" ]; then
    echo "### Configuring SSH..."
    rc-update add sshd default
    mkdir /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 750 /root/.ssh
    chmod 640 /root/.ssh/authorized_keys
    echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
fi
END

echo "### Rebooting..."

reboot
