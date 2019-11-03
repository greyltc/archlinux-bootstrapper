#!/usr/bin/env bash
set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

CURDIR=$(pwd)
TMPDIR=$(mktemp -d /var/tmp/genbootstrap.XXXXXX)

build_root() {
  sudo mkdir -p "${TMPDIR}"/root
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
  sudo mkdir -p "${TMPDIR}"/genroot
  sudo pacstrap -C "${TMPDIR}"/pacman.conf -c -d -G -M "${TMPDIR}"/root arch-install-scripts systemd
  sudo rm "${TMPDIR}"/root/var/lib/pacman/sync/*
}

fetch_root() {
  pushd "${TMPDIR}"
  wget --continue -nv -e robots=off -r --no-parent -A 'archlinux-bootstrap-*' https://mirrors.edge.kernel.org/archlinux/iso/latest/
  cp mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-bootstrap-* .

  # verify .sig
  gpg --no-default-keyring --keyring ./vendors.gpg --keyserver keyserver.ubuntu.com --recv-keys 4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC
  gpg --no-default-keyring --keyring ./vendors.gpg --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --no-default-keyring --keyring ./vendors.gpg --import-ownertrust
  gpg --trust-model always --no-default-keyring --keyring ./vendors.gpg --verify *.sig
  rm *.sig

  sudo tar xzf archlinux-bootstrap-*-x86_64.tar.gz
  sudo mv root.x86_64 root

  popd
}

if [ -f "/etc/arch-release" ]; then
  build_root
else
  fetch_root
fi

sudo mkdir -p "${TMPDIR}"/root-bind
sudo mount --bind "${TMPDIR}"/root "${TMPDIR}"/root-bind

cat > "${TMPDIR}"/setup-tasks.sh << "EOF"
#!/usr/bin/env bash
set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

pacman-key --init
pacman-key --populate archlinux
#cd /root

curl -L -o /etc/pacman.d/mirrorlist.backup https://www.archlinux.org/mirrorlist/all/https/
cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist

pacman -Syyu --needed --noconfirm sed pacman-contrib base

LOCALE=en_US.UTF-8
CHARSET=UTF-8
sed -i "s,^#${LOCALE} ${CHARSET},${LOCALE} ${CHARSET},g" /etc/locale.gen
localectl set-locale LANG=${LOCALE}
locale-gen

# setup package building stuff
groupadd builders
useradd -m -s /bin/bash builder
usermod -a -G wheel builder
usermod -a -G builders builder
MAKEPKG_BACKUP="/var/cache/makepkg/pkg"
mkdir -p "${MAKEPKG_BACKUP}"
chgrp builders "${MAKEPKG_BACKUP}"
chmod g+w "${MAKEPKG_BACKUP}"
sed -i "s,^#PKGDEST=.*$,PKGDEST=${MAKEPKG_BACKUP},g" /etc/makepkg.conf
sed -i 's,^#MAKEFLAGS=.*$,MAKEFLAGS="-j2",g' /etc/makepkg.conf

#sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
#rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

#pacman -Syyu --needed --noconfirm vim base-devel git
pacman -Syyu --needed --noconfirm vim
EOF
chmod +x "${TMPDIR}"/setup-tasks.sh
sudo mv "${TMPDIR}"/setup-tasks.sh "${TMPDIR}"/root-bind/usr/bin/setup-tasks.sh

sudo "${TMPDIR}"/root-bind/bin/arch-chroot "${TMPDIR}"/root-bind/ setup-tasks.sh
sudo rm "${TMPDIR}"/root-bind/bin/setup-tasks.sh
sudo umount "${TMPDIR}"/root-bind

sudo sh -c "(cd ${TMPDIR}/root; bsdtar -cf - * | pigz -9 > ${TMPDIR}/root.tar.gz)"
mv "${TMPDIR}/root.tar.gz" "${CURDIR}/root.tar.gz"
#sudo rm -rf "${TMPDIR}"
echo ${TMPDIR} > TMPDIR

