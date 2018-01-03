#!/bin/sh
qemu-system-x86_64 -drive format=raw,file=img.img -m 1024 -device usb-kbd -device usb-mouse -usb
