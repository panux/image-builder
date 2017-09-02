#!/bin/busybox sh

echo "Starting rescue shell"
echo "Installing busybox"
/bin/busybox --install -s
echo "Starting shell. Good luck!"
exec /bin/sh
