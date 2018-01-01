#!/bin/sh

set -e

fail() {
    echo "$@"
    sleep 10
    exec sh
}

mount -t devtmpfs none /dev || fail dev
mount -t proc none /proc || fail mnt proc
mount -t sysfs none /sys || fail mnt sys
clear || fail clear
sleep 3 || fail sleep
mount UUID=$(cat /uuid) /mnt || fail mnt
mount -t proc none /mnt/proc || fail mnt proc
mount -t sysfs none /mnt/sys || fail mnt sys
umount /dev || fail umount /dev
umount /proc || fail umount /dev
umount /sys || fail umount /dev
mount -t devtmpfs none /mnt/dev || fail mnt dev
clear || fail clear
exec switch_root /mnt /bin/init || fail switch root
