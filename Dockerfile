# This image starts from kubevirt/virt-launcher:v0.10.0, patches it, and
# is intended to then replace it.
# To make sure we always start from the original upstream copy, we start
# from the SHA hash instead of the image tag (which would be replaced)
#
# The main goal is to get an up-to-date version of libvirt and qemu,
# so that we can hardware-accelerate Android-x86
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
