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

FROM fedora:28 AS qemu-build

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
 bison \
#libvirt
 libxslt \
 gnutls-devel \
 libnl3-devel \
 libxml-devel \
 libxml2-devel \
 yajl-devel \
 device-mapper-devel \
 libpciaccess-devel \
 gettext \
 gettext-devel \
 rpcgen \
 libtirpc-devel

ARG QEMU_SOURCE_VERSION=3.1.0-rc5
ARG VIRGL_SOURCE_BRANCH=virglrenderer-0.7.0
# Make sure to use v4.10.0 + the patches which make sure /dev/dri/renderD128 has the correct permissions
ARG LIBVIRT_SOURCE_BRANCH=v4.10.1

WORKDIR /src

# Get the sources
RUN cd /src \
&& git clone -b ${VIRGL_SOURCE_BRANCH} https://github.com/freedesktop/virglrenderer \
&& wget https://download.qemu.org/qemu-${QEMU_SOURCE_VERSION}.tar.xz \
&& tar xvJf qemu-${QEMU_SOURCE_VERSION}.tar.xz \
&& rm qemu-${QEMU_SOURCE_VERSION}.tar.xz \
&& git clone -b $LIBVIRT_SOURCE_BRANCH --depth=1 https://github.com/kubedroid/libvirt/

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

# Compile libvirt
# RUN cd /src/libvirt \
# && git status . \
# && export CFLAGS="-Wno-unused-variable" \
# && ./autogen.sh --prefix=/usr \
# && make -j$(nproc) \
# && make install \
# && DESTDIR=/target/ make install \
# && cd /src

FROM docker.io/kubevirt/virt-launcher@sha256:ba612dd4b4373ca3cf4073188314955d5529a76ff0a7b08cc36c74847d1f3e42

ARG LIBVIRT_PACKAGE_VERSION=4.10.0
ARG QEMU_PACKAGE_VERSION=3.0.0
ARG LIBUSB_PACKAGE_VERSION=1.0.22

RUN dnf install -y dnf-plugins-core \
&& dnf copr enable -y @virtmaint-sig/virt-preview \
&& dnf install -y \
     libvirt-daemon-kvm-$LIBVIRT_PACKAGE_VERSION \
     libvirt-client-$LIBVIRT_PACKAGE_VERSION \
#     qemu-kvm-$QEMU_PACKAGE_VERSION \
     libusbx-$LIBUSB_PACKAGE_VERSION \
     mesa-dri-drivers \
&& dnf clean all

RUN mv /usr/bin/virt-launcher /usr/bin/upstream-virt-launcher
COPY --from=launcher-build /go/src/virt-launcher/virt-launcher /usr/bin/
COPY --from=qemu-build /target/usr /usr
