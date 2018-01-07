FROM panux/panux:x86_64

RUN echo y | lpkg install linux grub-bios linit linit-modules-load dhcpcd eudev xf86-video-vesa xf86-input-libinput lxde-core lxdm swrast-dri mesa-demos && \
    /etc/init.d/printk enable && \
    /etc/init.d/login enable && \
    /etc/init.d/dhcpcd enable && \
    /etc/init.d/eudev enable && \
    /etc/init.d/modules-load enable
RUN echo 'exec startlxde' > /root/.xinitrc
RUN gdk-pixbuf-query-loaders > /usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
RUN ln -s /usr/share/X11/xorg.conf.d/40-libinput.conf /etc/X11/xorg.conf.d/40-libinput.conf
RUN mkdir -p /root/.config/openbox && cp /etc/xdg/openbox/rc.xml /root/.config/openbox/lxde-rc.xml
RUN echo root:x:0:0:root:/root:/bin/sh > /etc/passwd && \
    echo root::0:0:99999:7::: > /etc/shadow
