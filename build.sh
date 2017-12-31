#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

rm -r irfs img.img mnt rootfs || echo Clean
docker rm rootfsimg || echo Clean

#create and mount disk image
dd if=/dev/zero of=img.img bs=1M count=128
LOOP=$(losetup -f)
losetup $LOOP img.img
#cleanup on exit
cleanup() {
    umount mnt || echo Not mount
    losetup -d $LOOP
}
trap cleanup EXIT

disk=$LOOP

[ -x "$(command -v git)" ] || { echo "Command missing: git"; echo "Cancelling"; exit 1; }
[ -x "$(command -v lua)" ] || { echo "Command missing: lua"; echo "Cancelling"; exit 1; }
[ -x "$(command -v cpio)" ] || { echo "Command missing: mkinitcpio"; echo "Cancelling"; exit 1; }
[ -x "$(command -v minisign)" ] || { echo "Command missing: minisign"; echo "Cancelling"; exit 1; }
[ -x "$(command -v parted)" ] || { echo "Command missing: parted"; echo "Cancelling"; exit 1; }
[ -x "$(command -v arch-chroot)" ] || { echo "Command missing: arch-chroot"; echo "Cancelling"; exit 1; }

echo "Building initramfs"
mkdir irfs
echo "Done building initramfs structutre"

echo "Building rootfs"
docker build . -t panux/image
docker run --name rootfsimg panux/image
mkdir rootfs
docker export rootfsimg | tar -xf - -C rootfs
cp inittab rootfs/etc/inittab
for i in $(ls init.d); do
    cp init.d/$i rootfs/etc/init.d/$(basename $i .sh)
    chmod +x rootfs/etc/init.d/$(basename $i .sh)
done
echo "Setup root password for bootable system"
chroot rootfs /usr/bin/passwd root
read -p "Enter name for new non-root user: " user
chroot rootfs /usr/bin/adduser $user
echo "Done with rootfs"

echo "Partitioning device"
parted -s -a optimal "$disk" mklabel msdos -- mkpart primary ext4 1 -1
mkdir mnt
mnt=$(realpath mnt)
echo "Formatting partitions. . . "
mkfs.ext4 "$disk"p1
echo "Copying rootfs to device"
mount "$disk"p1 $mnt
cp -r rootfs/* $mnt
echo "Installing bootloaders"
grub-install --target=i386-pc --no-floppy --grub-mkdevicemap=$PWD/boot/grub/device.map --root-directory=$PWD/mnt $LOOP
echo "Deleting everything other than boot files"
for file in `ls mnt`; do
    if [[ "$file" != boot ]]; then
        rm -r mnt/$file
    fi
done

echo "Generating initrd"
uuid=$(lsblk -no UUID "$disk"p1)
if [ -z "$uuid" ]; then
    echo "No uuid found"
    exit 2
fi
echo "$uuid" > irfs/uuid
echo "Copying rootfs to initrd"
cp -r rootfs/* irfs
cp init.sh irfs/init
chmod +x irfs/init
echo "Generating and installing initrd"
(cd irfs && find . | cpio -H newc -o | gzip > $mnt/boot/initramfs.igz)
echo "Generating grub config"
echo "search --no-floppy --fs-uuid --set root $uuid" > $mnt/boot/grub/grub.cfg
cat grub.cfg >> $mnt/boot/grub/grub.cfg
grub-install --target=i386-pc --no-floppy --grub-mkdevicemap=$PWD/boot/grub/device.map --root-directory=$PWD/mnt $LOOP

echo "Unmounting partitions"
umount $mnt
