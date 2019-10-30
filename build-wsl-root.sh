#!/usr/bin/env bash

set -e -u -o pipefail

wget -nv -e robots=off -r --no-parent -A 'archlinux-bootstrap-*' https://mirrors.edge.kernel.org/archlinux/iso/latest/
mv mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-bootstrap-* .
rm -rf mirrors.edge.kernel.org

gpg --no-default-keyring --keyring vendors.gpg --keyserver keyserver.ubuntu.com --recv-keys 4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC
gpg --no-default-keyring --keyring vendors.gpg --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --no-default-keyring --keyring vendors.gpg --import-ownertrust
gpg --no-default-keyring --keyring vendors.gpg --verify *.sig

rm *.sig vendors.gpg

mv archlinux-bootstrap-* install.tar.gz

mkdir rootmount
archivemount install.tar.gz rootmount

arch-chroot rootmount
touch poop

exit
unmount rootmount

