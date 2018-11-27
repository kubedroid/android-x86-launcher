# This image starts from kubevirt/virt-launcher:v0.10.0, patches it, and
# is intended to then replace it.
# To make sure we always start from the original upstream copy, we start
# from the SHA hash instead of the image tag (which would be replaced)
#
# The main goal is to get an up-to-date version of libvirt and qemu,
# so that we can hardware-accelerate Android-x86
FROM golang:1.11 AS launcher-build

WORKDIR /go/src/virt-launcher

COPY *.go .
RUN go build

FROM docker.io/kubevirt/virt-launcher:v0.10.0 AS upstream

FROM fedora:27 AS qemu-build

RUN dnf install -y \
 wget \
 make \
 automake \
 gcc \
 libtool \
 libdrm-devel \
 libgbm-devel \
 libepoxy-devel \
# python3 \
 git \
 mesa-libEGL-devel \
 xz \
 python \
 zlib-devel \
 glib2-devel \
 pixman-devel \
 spice-server-devel

# Compile virglrenderer
RUN cd ~ \
&& git clone -b virglrenderer-0.7.0 https://github.com/freedesktop/virglrenderer \
&& cd virglrenderer \
&& ./autogen.sh --prefix=/usr --disable-glx \
&& make -j$(nproc) \
&& make install


RUN cd ~ \
&& wget https://download.qemu.org/qemu-3.0.0.tar.xz \
&& tar xvJf qemu-3.0.0.tar.xz \
&& cd qemu-3.0.0 \
&& ./configure --enable-virglrenderer --enable-vnc --enable-spice --target-list="x86_64-softmmu" --disable-sdl --disable-gtk --prefix=/usr \
&& make -j$(nproc) \
&& make install

FROM 9b33dab9e7d75ecbbbb4c599dd9c0e1ab9f6f126fe605989bc86d8a7e80de9fc

ARG LIBVIRT_VERSION=4.9.0
ARG QEMU_VERSION=3.0.0
ARG LIBUSB_VERSION=1.0.22

RUN dnf install -y dnf-plugins-core \
&& dnf copr enable -y @virtmaint-sig/virt-preview \
&& dnf install -y \
     libvirt-daemon-kvm-$LIBVIRT_VERSION \
     libvirt-client-$LIBVIRT_VERSION \
     qemu-kvm-$QEMU_VERSION \
     libusbx-$LIBUSB_VERSION \
      mesa-dri-drivers \
&& dnf clean all

COPY --from=upstream /usr/bin/virt-launcher /usr/bin/upstream-virt-launcher
COPY --from=launcher-build /go/src/virt-launcher/virt-launcher /usr/bin/
