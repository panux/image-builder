FROM panux/panux:x86_64

RUN echo y | lpkg install linux linux-firmware grub-bios linit dhcpcd eudev && \
    /etc/init.d/printk enable && \
    /etc/init.d/login enable && \
    /etc/init.d/dhcpcd enable && \
    /etc/init.d/eudev enable
RUN echo root:x:0:0:root:/root:/bin/sh > /etc/passwd && \
    echo root::0:0:99999:7::: > /etc/shadow
