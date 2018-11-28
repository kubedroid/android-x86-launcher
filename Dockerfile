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
 git \
 mesa-libEGL-devel \
 xz \
 python \
 zlib-devel \
 glib2-devel \
 pixman-devel \
 spice-server-devel \
 patch \
 flex \
 bison

ARG QEMU_SOURCE_VERSION=3.1.0-rc1
ARG VIRGL_SOURCE_BRANCH=master

WORKDIR /src

# Get the sources
RUN cd /src \
&& git clone -b ${VIRGL_SOURCE_BRANCH} https://github.com/freedesktop/virglrenderer \
&& wget https://download.qemu.org/qemu-${QEMU_SOURCE_VERSION}.tar.xz \
&& tar xvJf qemu-${QEMU_SOURCE_VERSION}.tar.xz \
&& rm qemu-${QEMU_SOURCE_VERSION}.tar.xz

# Compile virglrenderer
RUN cd /src \
&& cd virglrenderer \
&& ./autogen.sh --prefix=/usr --disable-glx \
&& make -j$(nproc) \
&& make install \
&& DESTDIR=/target/ make install \
&& cd /src

# Apply the qemu patch, and compile qemu
COPY qemu.patch .
RUN cd /src \
&& cd qemu-${QEMU_SOURCE_VERSION} \
&& patch -p1 < ../qemu.patch \
&& ./configure --enable-virglrenderer --enable-vnc --enable-spice --target-list="x86_64-softmmu" --disable-sdl --disable-gtk --prefix=/usr \
&& make -j$(nproc) \
&& make install \
&& DESTDIR=/target/ make install \
&& cd /src

FROM 9b33dab9e7d75ecbbbb4c599dd9c0e1ab9f6f126fe605989bc86d8a7e80de9fc

ARG LIBVIRT_PACKAGE_VERSION=4.9.0
ARG QEMU_PACKAGE_VERSION=3.0.0
ARG LIBUSB_PACKAGE_VERSION=1.0.22

RUN dnf install -y dnf-plugins-core \
&& dnf copr enable -y @virtmaint-sig/virt-preview \
&& dnf install -y \
     libvirt-daemon-kvm-$LIBVIRT_PACKAGE_VERSION \
     libvirt-client-$LIBVIRT_PACKAGE_VERSION \
     qemu-kvm-$QEMU_PACKAGE_VERSION \
     libusbx-$LIBUSB_PACKAGE_VERSION \
     mesa-dri-drivers \
&& dnf clean all

RUN mv /usr/bin/virt-launcher /usr/bin/upstream-virt-launcher
COPY --from=launcher-build /go/src/virt-launcher/virt-launcher /usr/bin/
COPY --from=qemu-build /target/usr /usr
