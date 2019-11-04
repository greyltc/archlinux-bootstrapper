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

AUR_PACKAGES="linux-wsl adduser-deb"

su -c "(cd; git clone https://aur.archlinux.org/fakeroot-tcp.git)" -s /bin/bash builder
su -c "(cd; cd fakeroot-tcp; source /etc/profile.d/perlbin.sh; makepkg -Cfs --needed --noconfirm)" -s /bin/bash builder
su -c "(cd; rm -rf fakeroot-tcp)" -s /bin/bash builder
su -c "(cd /var/cache/makepkg/pkg/; yes | pacman -U fakeroot-tcp*.pkg.tar.xz)" -s /bin/bash root

su -c "(cd; git clone https://aur.archlinux.org/yay.git)" -s /bin/bash builder
su -c "(cd; cd yay; unset GOROOT; makepkg -Cfsi --needed --noconfirm)" -s /bin/bash builder
su -c "(cd; rm -rf yay)" -s /bin/bash builder

su -c "(yay -Syyu --needed --noconfirm ${AUR_PACKAGES})" -s /bin/bash builder

# clean up
rm -rf /home/builder/.cache/yay
libtool --finish /usr/lib/libfakeroot
sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers
EOF

chmod +x "${TMPDIR}"/setup-tasks.sh
sudo mv "${TMPDIR}"/setup-tasks.sh "${TMPDIR}"/root-bind/usr/bin/setup-tasks.sh

cat > "${TMPDIR}"/wsl-native-setup << "EOF"
#!/usr/bin/env bash
set -o pipefail
set -o errexit
set -o nounset
#set -o verbose
#set -o xtrace

reflect-mirrors
echo "Setting up keyring..."
pacman-key --init
pacman-key --populate archlinux
echo "Updating software packages..."
pacman -Syyu --noconfirm
EOF
chmod +x "${TMPDIR}"/wsl-native-setup
sudo mv "${TMPDIR}"/wsl-native-setup "${TMPDIR}"/root-bind/usr/bin/wsl-native-setup

sudo "${TMPDIR}"/root-bind/bin/arch-chroot "${TMPDIR}"/root-bind/ setup-tasks.sh
sudo rm "${TMPDIR}"/root-bind/bin/setup-tasks.sh
sudo umount "${TMPDIR}"/root-bind

