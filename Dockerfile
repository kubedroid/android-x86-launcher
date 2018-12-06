# This image starts from kubevirt/virt-launcher:v0.10.0, patches it, and
# is intended to then replace it.
# To make sure we always start from the original upstream copy, we start
# from the SHA hash instead of the image tag (which would be replaced)
#
# The main goal is to get an up-to-date version of libvirt and qemu,
# so that we can hardware-accelerate Android-x86
FROM golang:1.11 AS upstream-build

WORKDIR /usr/local/go/src/kubevirt.io

RUN git config --global user.email "frederik.carlier@quamotion.mobi" \
&& git config --global user.name "Frederik Carlier"

RUN apt-get update \
&& apt-get install -y libvirt-dev \
&& rm -rf /var/lib/apt/lists/*

RUN git clone -b release-0.10 https://github.com/kubevirt/kubevirt/ \
&& cd kubevirt \
&& git remote add rmohr https://github.com/rmohr/kubevirt \
&& git fetch rmohr \
&& git cherry-pick 3445986c3d74e91be3a635852abc4b105065e36e \
&& git cherry-pick 10472f8a886d80e793d00453b4cbab36e45a4328

RUN cd kubevirt/cmd/virt-launcher \
/&& mkdir -p /usr/local/bin/ \
&& GOOS=linux GOARCH=amd64 go build

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
 gettext-devel

ARG QEMU_SOURCE_VERSION=3.1.0-rc4
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

# Compile libvirt
RUN git clone -b v4.10.0 --depth=1 https://github.com/kubedroid/libvirt/

RUN cd /src/libvirt \
&& git status . \
&& export CFLAGS="-Wno-unused-variable" \
&& ./autogen.sh --prefix=/usr \
&& make -j$(nproc) \
&& make install \
&& DESTDIR=/target/ make install \
&& cd /src

FROM docker.io/kubevirt/virt-launcher@sha256:8f8ccfb5281916ee77792f7d92182db11f4205d523fb826c6e21e73b09a5f3a7

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

COPY --from=upstream-build /usr/local/go/src/kubevirt.io/kubevirt/cmd/virt-launcher/virt-launcher /usr/bin/upstream-virt-launcher
# mv /usr/bin/virt-launcher /usr/bin/upstream-virt-launcher
COPY --from=launcher-build /go/src/virt-launcher/virt-launcher /usr/bin/
COPY --from=qemu-build /target/usr /usr

RUN chmod +x /usr/bin/upstream-virt-launcher
