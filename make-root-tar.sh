#!/usr/bin/env bash

set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

CURDIR=$(pwd)
TMPDIR=$(mktemp -d /tmp/genbootstrap.XXXXXX)

cat > "${TMPDIR}"/pacman.conf << "EOF"
[options]
Architecture = auto
CheckSpace
Color
SigLevel = Required DatabaseOptional
[core]
Include = /etc/pacman.d/mirrorlist
[extra]
Include = /etc/pacman.d/mirrorlist
[community]
Include = /etc/pacman.d/mirrorlist
EOF

sudo mkdir "${TMPDIR}"/root
sudo pacstrap -C "${TMPDIR}"/pacman.conf -c -d -G -M "${TMPDIR}"/root/ arch-install-scripts systemd
sudo rm "${TMPDIR}"/root/var/lib/pacman/sync/*

cat > "${TMPDIR}"/setup-tasks.sh << "EOF"
touch poop
echo "poop touched!"
EOF
chmod +x "${TMPDIR}"/setup-tasks.sh
sudo mv "${TMPDIR}"/setup-tasks.sh "${TMPDIR}"/root/usr/bin/setup-tasks.sh

sudo "${TMPDIR}"/root/bin/arch-chroot "${TMPDIR}"/root/ setup-tasks.sh
sudo rm "${TMPDIR}"/root/bin/setup-tasks.sh

sudo sh -c "(cd ${TMPDIR}/root; bsdtar -cf - * | gzip -9 > ${TMPDIR}/root.tar.gz)"
mv "${TMPDIR}/root.tar.gz" "${CURDIR}/root.tar.gz"
sudo rm -rf "${TMPDIR}"

