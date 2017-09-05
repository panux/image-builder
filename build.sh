#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

FILES=(irfs lpkg mnt rootfs busybox)

for file in $FILES; do
    if [[ -e $file ]]; then
        echo "Detected unclean environment. Please clean up and try again."
        exit 1
    fi
done

read -p "Enter drive to install onto (e.g. /dev/sdc): " disk

if [ ! -b "$disk" ]; then
    if [ -e "$disk" ]; then
        echo "Specified file is not a block device"
        exit 1
    fi
    echo "Specified drive does not exist"
    exit 1
fi

echo "WARNING: THIS WILL DESTROY ALL DATA ON THE SPECIFIED DEVICE"
read -p "Are you sure you want to proceed (y/N)? " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelling. . . "
    exit 1
fi

echo "Starting in 10 seconds. Press control-C to cancel. Last chance to safely cancel."
sleep 10
echo "Started"

[ -x "$(command -v git)" ] || { echo "Command missing: git"; echo "Cancelling"; exit 1; }
[ -x "$(command -v lua)" ] || { echo "Command missing: lua"; echo "Cancelling"; exit 1; }
[ -x "$(command -v cpio)" ] || { echo "Command missing: mkinitcpio"; echo "Cancelling"; exit 1; }
[ -x "$(command -v minisign)" ] || { echo "Command missing: minisign"; echo "Cancelling"; exit 1; }
[ -x "$(command -v parted)" ] || { echo "Command missing: parted"; echo "Cancelling"; exit 1; }
[ -x "$(command -v arch-chroot)" ] || { echo "Command missing: arch-chroot"; echo "Cancelling"; exit 1; }

set -e

echo "Downloading busybox"
curl https://www.busybox.net/downloads/binaries/1.21.1/busybox-x86_64 > busybox
chmod 700 busybox
./busybox --list
echo "busybox done"

echo "Building initramfs"
mkdir irfs
mkdir irfs/proc irfs/sys irfs/dev irfs/bin
cp busybox irfs/bin/busybox
chroot irfs /bin/busybox --install -s /bin
cp initrdscripts/init.sh irfs/init
cp initrdscripts/emergency.sh irfs/emergency
chmod 700 irfs/init
chmod 700 irfs/emergency
echo "Done building initramfs structutre"

echo "Building rootfs"
git clone https://github.com/panux/lpkg.git
echo "Bootstrapping rootfs. . . "
lua lpkg/lpkg.lua bootstrap repo.projectpanux.com beta x86_64 $(pwd)/rootfs base linux linux-firmware grub-efi
cp inittab rootfs/etc/inittab
echo "Setting up users"
echo root:x:0:0:root:/root:/bin/sh > rootfs/etc/passwd
echo root::0:0:99999:7::: > rootfs/etc/shadow
echo "Setup root password for bootable system"
chroot rootfs /usr/bin/passwd root
read -p "Enter name for new non-root user: " user
chroot rootfs /usr/bin/adduser $user
echo "Done with rootfs"

echo "Partitioning device"
parted -s $disk mklabel gpt
parted -s -a none $disk mkpart ESP fat32 0 4M
parted -s -a none $disk mkpart linux ext4 4M 128M
mkdir mnt
mnt=$(realpath mnt)
echo "Formatting partitions. . . "
mkfs.msdos -F 32 "$disk"1
mkfs.ext4 "$disk"2
echo "Copying rootfs to device"
mount "$disk"2 $mnt
cp -r rootfs/* $mnt
mkdir $mnt/boot/efi
mount "$disk"1 $mnt/boot/efi
echo "Installing bootloaders"
arch-chroot $mnt /usr/sbin/grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub

echo "Finishing initrd"
uuid=$(lsblk -no UUID "$disk"2)
if [ -z "$uuid" ]; then
    echo "No uuid found"
    exit 2
fi
bootuuid=$(lsblk -no UUID "$disk"1)
if [ -z "$uuid" ]; then
    echo "No boot partition uuid found"
    exit 2
fi
echo "$uuid" > irfs/uuid
echo "Generating and installing initrd"
(cd irfs && find . | cpio -H newc -o | gzip > $mnt/boot/initramfs.igz)
echo "Generating grub config"
echo "search --no-floppy --fs-uuid --set root $bootuuid" > $mnt/boot/grub/grub.cfg
cat grub.cfg >> $mnt/boot/grub/grub.cfg

echo "Unmounting partitions"
umount $mnt/boot/efi
umount $mnt
