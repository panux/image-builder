#!/bin/busybox sh

fail() {
    echo "$1"
    exec /emergency
}

mntfail() {
    fail "Failed to mount $1"
}
echo "Mounting /proc /sys /dev"
mount -t proc none /proc || mntfail /proc
mount -t sysfs none /sys || mntfail /sys
mount -t devtmpfs none /dev || mntfail /dev

echo "Finding filesystem"
UUID=$(cat /uuid) || UUID=""
[ "$UUID" == "" ] && fail "UUID missing"
echo "Searching for UUID $UUID"
FS=$(findfs "$UUID") || FS=""
[ "$FS" == "" ] && fail "Could not find filesystem"
echo "Found filesystem with UUID $UUID at $FS"

echo "Mounting filesystem"
mount -o ro $FS /mnt

umnt() {
    umount "$1" || fail "Failed to unmount $1"
}
echo "Unmounting temporary filesystems"
umnt /proc
umnt /sys
umnt /dev

echo "Starting system"
exec switch_root /mnt /bin/init || fail "Failed to start system"
