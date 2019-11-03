#!/usr/bin/env bash

set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

TMPDIR="$1"
CURDIR=$(pwd)

echo ${TMPDIR}

cat > "${TMPDIR}"/setup-tasks.sh << "EOF"
#!/usr/bin/env bash
set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

touch poop

EOF

chmod +x "${TMPDIR}"/setup-tasks.sh
sudo mv "${TMPDIR}"/setup-tasks.sh "${TMPDIR}"/root-bind/usr/bin/setup-tasks.sh

sudo "${TMPDIR}"/root-bind/bin/arch-chroot "${TMPDIR}"/root-bind/ setup-tasks.sh
sudo rm "${TMPDIR}"/root-bind/bin/setup-tasks.sh
sudo umount "${TMPDIR}"/root-bind

sudo sh -c "(cd ${TMPDIR}/root; bsdtar -cf - * | gzip -9 > ${TMPDIR}/root.tar.gz)"

mv "${TMPDIR}/root.tar.gz" "${CURDIR}/root-wsl.tar.gz"

