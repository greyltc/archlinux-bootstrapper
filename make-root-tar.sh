#!/usr/bin/env bash
set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

CURDIR=$(pwd)
TMPDIR=$(mktemp -d /tmp/genbootstrap.XXXXXX)

build_root() {
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
  sudo pacstrap -C "${TMPDIR}"/pacman.conf -c -d -G -M "${TMPDIR}"/genroot arch-install-scripts systemd
  sudo rm "${TMPDIR}"/genroot/var/lib/pacman/sync/*
  sudo mount --bind "${TMPDIR}"/genroot "${TMPDIR}"/root
}

fetch_root() {
  pushd "${TMPDIR}"
  wget --continue -nv -e robots=off -r --no-parent -A 'archlinux-bootstrap-*' https://mirrors.edge.kernel.org/archlinux/iso/latest/
  cp mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-bootstrap-* .

  # verify .sig
  gpg --no-default-keyring --keyring ./vendors.gpg --keyserver keyserver.ubuntu.com --recv-keys 4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC
  gpg --no-default-keyring --keyring ./vendors.gpg --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --no-default-keyring --keyring ./vendors.gpg --import-ownertrust
  gpg --no-default-keyring --keyring ./vendors.gpg --verify *.sig
  rm vendors.gpg* *.sig

  sudo tar xzf archlinux-bootstrap-*-x86_64.tar.gz

  sudo ln -s root.x86_64 root
  sudo mount --bind root.x86_64 root
  sudo rm root/README
  popd
}

sudo mkdir -p "${TMPDIR}"/root
if [ -f "/etc/arch-release" ]; then
  build_root
else
  fetch_root
fi

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

pacman -Syyu --noconfirm sed pacman-contrib

LOCALE=en_US.UTF-8
CHARSET=UTF-8
sed -i "s,^#${LOCALE} ${CHARSET},${LOCALE} ${CHARSET},g" /etc/locale.gen
locale-gen
localectl set-locale LANG=${LOCALE}

sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

pacman -Syyu --noconfirm vim
EOF
chmod +x "${TMPDIR}"/setup-tasks.sh
sudo mv "${TMPDIR}"/setup-tasks.sh "${TMPDIR}"/root/usr/bin/setup-tasks.sh

sudo "${TMPDIR}"/root/bin/arch-chroot "${TMPDIR}"/root/ setup-tasks.sh
sudo rm "${TMPDIR}"/root/bin/setup-tasks.sh

sudo sh -c "(cd ${TMPDIR}/root; bsdtar -cf - * | gzip -9 > ${TMPDIR}/root.tar.gz)"
mv "${TMPDIR}/root.tar.gz" "${CURDIR}/root.tar.gz"
sudo umount "${TMPDIR}"/root
sudo rm -rf "${TMPDIR}"

