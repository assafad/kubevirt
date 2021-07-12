#!/usr/bin/env bash

set -ex

source hack/common.sh
source hack/config.sh

LIBVIRT_VERSION=0:7.0.0-12
SEABIOS_VERSION=0:1.14.0-1
QEMU_VERSION=15:5.2.0-15

# Packages that we want to be included in all container images.
#
# Further down we define per-image package lists, which are just like
# this one are split into two: one for the packages that we actually
# want to have in the image, and one for (indirect) dependencies that
# have more than one way of being resolved. Listing the latter
# explicitly ensures that bazeldnf always reaches the same solution
# and thus keeps things reproducible
fedora_base="
  curl-minimal
  vim-minimal
"
fedora_extra="
  coreutils-single
  fedora-logos-httpd
  glibc-langpack-en
  libcurl-minimal
"

# get latest repo data from repo.yaml
bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- fetch

# create a rpmtree for our test image with misc. tools.
testimage_base="
  device-mapper
  e2fsprogs
  iputils
  nmap-ncat
  procps-ng
  qemu-img
  util-linux
  which
"

bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- rpmtree --public --name testimage_x86_64 \
    $fedora_base \
    $fedora_extra \
    $testimage_base

bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- rpmtree --public --arch=aarch64 --name testimage_aarch64 \
    $fedora_base \
    $fedora_extra \
    $testimage_base

# create a rpmtree for libvirt-devel. libvirt-devel is needed for compilation and unit-testing.
libvirtdevel_base="
  libvirt-devel-${LIBVIRT_VERSION}
"
libvirtdevel_extra="
  keyutils-libs
  krb5-libs
  libmount
  lz4-libs
"

bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- rpmtree --public --name libvirt-devel_x86_64 \
    $fedora_base \
    $fedora_extra \
    $libvirtdevel_base \
    $libvirtdevel_extra

bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- rpmtree --public --arch=aarch64 --name libvirt-devel_aarch64 \
    $fedora_base \
    $fedora_extra \
    $libvirtdevel_base \
    $libvirtdevel_extra

# create a rpmtree for virt-launcher and virt-handler. This is the OS for our node-components.
launcherbase_base="
  libvirt-client-${LIBVIRT_VERSION}
  libvirt-daemon-driver-qemu-${LIBVIRT_VERSION}
  qemu-kvm-core-${QEMU_VERSION}
"
launcherbase_x86_64="
  seabios-${SEABIOS_VERSION}
"
launcherbase_extra="
  findutils
  iptables
  nftables
  procps-ng
  selinux-policy
  selinux-policy-targeted
  tar
  xorriso
"

bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- rpmtree --public --name launcherbase_x86_64 \
    --force-ignore-with-dependencies '^mozjs60' \
    $fedora_base \
    $fedora_extra \
    $launcherbase_base \
    $launcherbase_x86_64 \
    $launcherbase_extra

bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- rpmtree --public --arch=aarch64 --name launcherbase_aarch64 \
    --force-ignore-with-dependencies '^mozjs60' \
    $fedora_base \
    $fedora_extra \
    $launcherbase_base \
    $launcherbase_extra

handler_base="
  qemu-img-${QEMU_VERSION}
"

handlerbase_extra="
  findutils
  iproute
  iptables
  nftables
  procps-ng
  selinux-policy
  selinux-policy-targeted
  tar
  util-linux
  xorriso
"

# create a rpmtree for virt-handler
bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- rpmtree --public --arch=aarch64 --name handlerbase_aarch64 \
    $basesystem \
    $handler_base \
    $handlerbase_extra

bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- rpmtree --public --name handlerbase_x86_64 \
    $basesystem \
    $handler_base \
    $handlerbase_extra

libguestfstools_base="
  libguestfs
  libguestfs-tools
"

bazel run \
    //:bazeldnf -- rpmtree --public --name libguestfs-tools \
    $fedora_base \
    $fedora_extra \
    $libguestfstools_base \
    --force-ignore-with-dependencies '^(kernel-|linux-firmware)' \
    --force-ignore-with-dependencies '^(python[3]{0,1}-|perl[3]{0,1}-)' \
    --force-ignore-with-dependencies '^(mesa-|libwayland-|selinux-policy|mozjs60)' \
    --force-ignore-with-dependencies '^(libvirt-daemon-driver-storage|swtpm)' \
    --force-ignore-with-dependencies '^(man-db|mandoc)' \
    --force-ignore-with-dependencies '^(dbus|glusterfs|libX11|qemu-kvm-block|trousers|usbredir)' \
    --force-ignore-with-dependencies '^(gstreamer1|kbd|libX)'

# remove all RPMs which are no longer referenced by a rpmtree
bazel run \
    --config=${ARCHITECTURE} \
    //:bazeldnf -- prune

# FIXME: For an unknown reason the run target afterwards can get
# out dated tar files, build them explicitly first.
bazel build \
    --config=${ARCHITECTURE} \
    //rpm:libvirt-devel_x86_64

bazel build \
    --config=${ARCHITECTURE} \
    //rpm:libvirt-devel_aarch64
# update tar2files targets which act as an adapter between rpms
# and cc_library which we need for virt-launcher and virt-handler
bazel run \
    --config=${ARCHITECTURE} \
    //rpm:ldd_x86_64

bazel run \
    --config=${ARCHITECTURE} \
    //rpm:ldd_aarch64
