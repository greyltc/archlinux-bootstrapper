#!/usr/bin/env bash
set -o pipefail
set -o errexit
set -o nounset
set -o verbose
set -o xtrace

cd $TRAVIS_BUILD_DIR
git config user.name "Travis CI"
git config user.email "travis@rob.ot"

# use secrets
chmod 600 .travis_key.txt
eval `ssh-agent -s`
ssh-add .travis_key.txt
set +o xtrace
set +o verbose
GH_TOKEN=`cat .gh_token.txt`
# destroy their files
set -o verbose
set -o xtrace
rm .travis_key.txt .gh_token.txt .secrets.tar

./make-root-tar.sh |& tee root-build.log
git add root-build.log
#git add root.tar.gz
TMPDIR=$(cat TMPDIR)
rm TMPDIR
#./wsl-root-mod.sh "${TMPDIR}"|& tee wsl-mod.log
#git add wsl-mod.log
#git add root-wsl.tar.gz

sudo rm -rf "${TMPDIR}"

#git add root.tar.gz

GH_TAG="$(date -u -I)"

git commit -m "${GH_TAG}: rootfs built via travis"

export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

git remote set-url --push origin git@github.com:greyltc/archlinux-bootstrapper.git

git tag --annotate --force --message="${GH_TAG} generated by travis" "${GH_TAG}" master
#ssh-add -l
#ssh-add -L
#git config --local lfs.https://github.com/.locksverify false
git push origin master --force --tags

# publish asset(s)
GH_USER=greyltc
GH_PROJ=archlinux-bootstrapper
GH_BRANCH=master
GH_RELEASE="v${GH_TAG//-/.}"
set +o xtrace
set +o verbose
REL_RES="$(curl --data "{\"tag_name\": \"${GH_TAG}\",\"target_commitish\": \"${GH_BRANCH}\",\"name\": \"${GH_RELEASE}\",\"body\": \"Release of version ${GH_RELEASE/v/}\",\"draft\": false,\"prerelease\": false}" https://api.github.com/repos/${GH_USER}/${GH_PROJ}/releases?access_token=$GH_TOKEN)"
set -o verbose
set -o xtrace
REL_ID=`echo ${REL_RES} | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])'`

ASSET=root.tar.gz
LABEL="Compressed root file system (with no kernel)"
LABEL_ESC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$LABEL'))")
set +o xtrace
set +o verbose
curl -H "Authorization: token $GH_TOKEN" -H "Content-Type: $(file -b --mime-type $ASSET)" --data-binary @$ASSET "https://uploads.github.com/repos/${GH_USER}/${GH_PROJ}/releases/${REL_ID}/assets?name=${ASSET}&label=${LABEL_ESC}"
