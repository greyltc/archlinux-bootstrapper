#!/usr/bin/env bash

set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

#set -e -u -o pipefail

wget --continue -nv -e robots=off -r --no-parent -A 'archlinux-bootstrap-*' https://mirrors.edge.kernel.org/archlinux/iso/latest/
mkdir -p /tmp/rootwork
cp mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-bootstrap-* /tmp/rootwork/.
pushd /tmp/rootwork

# verify .sig
gpg --no-default-keyring --keyring ./vendors.gpg --keyserver keyserver.ubuntu.com --recv-keys 4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC
gpg --no-default-keyring --keyring ./vendors.gpg --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --no-default-keyring --keyring ./vendors.gpg --import-ownertrust
gpg --no-default-keyring --keyring ./vendors.gpg --verify *.sig
rm vendors.gpg* *.sig

tar xzf archlinux-bootstrap-*-x86_64.tar.gz

cat <<EOF > /tmp/setup-tasks.sh
touch poop
echo "poop touched!"
EOF
chmod +x /tmp/setup-tasks.sh
sudo sh -c 'mv /tmp/setup-tasks.sh  /tmp/rootwork/root.x86_64/usr/bin/.'

sudo /tmp/rootwork/root.x86_64/bin/arch-chroot /tmp/rootwork/root.x86_64/ setup-tasks.sh
sudo rm /tmp/rootwork/root.x86_64/bin/setup-tasks.sh

sudo sh -c 'cd /tmp/rootwork/root.x86_64 && tar -zcf ../root.tar.gz *'

popd

mv /tmp/rootwork/root.tar.gz .

rm -rf /tmp/rootwork
