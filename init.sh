#!/bin/sh

set -e

fail() {
    echo Failed "$@"
    echo Dropping to rescue shell
    exec sh
}

mount -t devtmpfs none /dev || fail dev
mount -t proc none /proc || fail proc
mount -t sysfs none /sys || fail sys
clear || fail clear
mount UUID=$(cat /uuid) /mnt || fail mnt
mount -t tmpfs none /mnt/tmp || fail mnt tmp
mount -t proc none /mnt/proc || fail mnt proc
mount -t sysfs none /mnt/sys || fail mnt sys
umount /dev || fail umount /dev
umount /proc || fail umount /proc
umount /sys || fail umount /sys
mount -t devtmpfs none /mnt/dev || fail mnt dev
mkdir /mnt/dev/pts || fail mkdir dev/pts
mount -t devpts devpts /mnt/dev/pts || fail mount dev/pts
clear || fail clear
exec switch_root /mnt /bin/init || fail switch root
