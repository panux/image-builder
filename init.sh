#!/bin/sh

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
echo 0 > /proc/sys/kernel/printk
sleep 3
clear
ln -s /etc/init.d/login /etc/rc.d/login
exec /bin/init
