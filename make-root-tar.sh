#!/usr/bin/env bash

set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

#set -e -u -o pipefail

wget --continue -nv -e robots=off -r --no-parent -A 'archlinux-bootstrap-*' https://mirrors.edge.kernel.org/archlinux/iso/latest/
cp mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-bootstrap-* .

# verify .sig
gpg --no-default-keyring --keyring ./vendors.gpg --keyserver keyserver.ubuntu.com --recv-keys 4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC
gpg --no-default-keyring --keyring ./vendors.gpg --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --no-default-keyring --keyring ./vendors.gpg --import-ownertrust
gpg --no-default-keyring --keyring ./vendors.gpg --verify *.sig
rm vendors.gpg* *.sig

mv archlinux-bootstrap-*.tar.gz root.tar.gz

mkdir mnt
sudo archivemount root.tar.gz mnt

sudo sh -c 'mv mnt/root.x86_64/* mnt/.'
sudo rm -rf mnt/root.x86_64

cat <<EOF > /tmp/setup-tasks.sh
touch poop
echo "poop touched!"
EOF
chmod +x /tmp/setup-tasks.sh
sudo mv /tmp/setup-tasks.sh  mnt/usr/bin/.

sudo arch-chroot mnt setup-tasks.sh
sudo rm mnt/usr/bin/setup-tasks.sh

sudo umount mnt
rm -rf mnt
