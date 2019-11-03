#!/usr/bin/env bash

set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

TMPDIR="$1"
CURDIR=$(pwd)

echo ${TMPDIR}

sudo mkdir -p "${TMPDIR}"/root-bind
sudo mount --bind "${TMPDIR}"/root "${TMPDIR}"/root-bind

cat > "${TMPDIR}"/setup-tasks.sh << "EOF"
#!/usr/bin/env bash
set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

pacman -Syyu --needed --noconfirm base-devel git po4a

cd /root
git clone https://aur.archlinux.org/fakeroot-tcp.git
cd fakeroot-tcp
makepkg -Cfis --needed --noconfirm
rm -rf fakeroot-tcp

git clone https://aur.archlinux.org/linux-wsl.git
cd linux-wsl
makepkg -Cfis --needed --noconfirm
#rm -rf linux-wsl

pacman -Rs --noconfirm base-devel git po4a
EOF

chmod +x "${TMPDIR}"/setup-tasks.sh
sudo mv "${TMPDIR}"/setup-tasks.sh "${TMPDIR}"/root-bind/usr/bin/setup-tasks.sh

sudo "${TMPDIR}"/root-bind/bin/arch-chroot "${TMPDIR}"/root-bind/ setup-tasks.sh
sudo rm "${TMPDIR}"/root-bind/bin/setup-tasks.sh
sudo umount "${TMPDIR}"/root-bind

sudo sh -c "(cd ${TMPDIR}/root; bsdtar -cf - * | gzip -9 > ${TMPDIR}/root.tar.gz)"

mv "${TMPDIR}/root.tar.gz" "${CURDIR}/root-wsl.tar.gz"

