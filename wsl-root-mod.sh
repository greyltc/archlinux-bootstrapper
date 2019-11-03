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

pacman -Syyu --needed --noconfirm base-devel git
sed -i 's,# %wheel ALL=(ALL),%wheel ALL=(ALL),g' /etc/sudoers

AUR_PACKAGES="linux-wsl"

su -c "(cd; git clone https://aur.archlinux.org/fakeroot-tcp.git)" -s /bin/bash builder
su -c "(cd; cd fakeroot-tcp; yes | makepkg -Cfsi --needed --noconfirm)" -s /bin/bash builder
su -c "(cd; rm -rf fakeroot-tcp)" -s /bin/bash builder

su -c "(cd; git clone https://aur.archlinux.org/yay.git)" -s /bin/bash builder
su -c "(cd; cd yay; makepkg -Cfsi --needed --noconfirm)" -s /bin/bash builder
su -c "(cd; rm -rf yay)" -s /bin/bash builder

su -c "(source /etc/profile.d/perlbin.sh; yay -Syyu --needed --noconfirm ${AUR_PACKAGES})" -s /bin/bash builder

# clean up
rm -rf /home/builder/.cache/yay
libtool --finish /usr/lib/libfakeroot
sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers
EOF

chmod +x "${TMPDIR}"/setup-tasks.sh
sudo mv "${TMPDIR}"/setup-tasks.sh "${TMPDIR}"/root-bind/usr/bin/setup-tasks.sh

sudo "${TMPDIR}"/root-bind/bin/arch-chroot "${TMPDIR}"/root-bind/ setup-tasks.sh
sudo rm "${TMPDIR}"/root-bind/bin/setup-tasks.sh
sudo umount "${TMPDIR}"/root-bind

sudo sh -c "(cd ${TMPDIR}/root; bsdtar -cf - * | pigz -9 > ${TMPDIR}/root.tar.gz)"

mv "${TMPDIR}/root.tar.gz" "${CURDIR}/root-wsl.tar.gz"

