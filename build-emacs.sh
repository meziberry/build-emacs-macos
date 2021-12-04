#!/bin/sh

## Derived from https://github.com/renard/emacs-build-macosx
## Patches from https://github.com/d12frosted/homebrew-emacs-plus
## See also https://github.com/jimeh/build-emacs-for-macos

set -e

ROOT_DIR="`pwd`"
BUILD_DIR=/tmp/emacs-build
SRC_DIR=emacs-git
GIT_VERSION=setup-emacs-git-version.el
SETUP=~/.emacs.d/setup-config

# ======================================================
# Start with a clean build
# ======================================================

rm -rf ${BUILD_DIR}
mkdir ${BUILD_DIR}

cd ${SRC_DIR}

# ======================================================
# Input for version otherwise default to master
# ======================================================

if test -n "$1"; then
    commit="$1"
else
    commit="origin/master"
    git pull
fi

git archive --format tar $commit | tar -C ${BUILD_DIR} -xvf -

REV=`git log -n 1 --no-color --pretty='format:%h' ${commit}`
TIMESTAMP=`git log -n 1 --no-color --pretty='format:%at' ${commit}`
PATCH_LIST=`find ${ROOT_DIR}/patches/ -name '*.patch'`
cd ${BUILD_DIR}

echo "
# ======================================================
# Record Git SHA
# ======================================================
"

cp ${ROOT_DIR}/site-lisp/${GIT_VERSION} ${BUILD_DIR}/
sed -e "s/@@GIT_COMMIT@@/$REV/" -i '' ${BUILD_DIR}/${GIT_VERSION}
mv -f ${BUILD_DIR}/${GIT_VERSION} ${SETUP}/${GIT_VERSION}

echo "DONE!"

echo "
# ======================================================
# Apply Patches
# ======================================================
"
# Note that this applies all patches in 'patches' dir
for f in ${PATCH_LIST}; do
    echo "Applying patch `basename $f`"
    patch -p1 -i $f
done

# ======================================================
# Info settings
# ======================================================

STRINGS="
  nextstep/templates/Emacs.desktop.in
  nextstep/templates/Info-gnustep.plist.in
  nextstep/templates/Info.plist.in
  nextstep/templates/InfoPlist.strings.in"

DAY=`date -u -r $TIMESTAMP +"%Y-%m-%d_%H-%M-%S"`
ORIG=`grep ^AC_INIT configure.ac`
VNUM=`echo $ORIG | sed 's#^AC_INIT(\(.*\))#\1#; s/ //g' | cut -f2 -d,`
VERS="$DAY Git $REV"
DESCR="Emacs_Cocoa_${VNUM}_${DAY}_Git_${REV}"

echo "
# ======================================================
# Autogen/copy_autogen
# ======================================================
"
./autogen.sh

for f in $STRINGS; do
    sed -e "s/@version@/@version@ $VERS/" -i '' $f
done

echo "
# ======================================================
# Configure emacs
# ======================================================
"

./configure \
    --with-dbus \
    --with-ns \
    --with-native-compilation \
    --with-xwidgets \
    --with-mailutils \
    --with-sound=yes \
    --with-json \

echo "
# ======================================================
# Build and install everything
# ======================================================
"

## Check number of processors
NCPU=$(getconf _NPROCESSORS_ONLN)

## Send output to log file using tee
## See https://stackoverflow.com/a/60432203/6277148
make bootstrap -j$NCPU | tee bootstrap-log.txt || exit 1 && make install -j$NCPU | tee build-log.txt

echo "DONE!"

echo "
# ======================================================
# Delete old app & Move new app
# ======================================================
"

pkill -i emacs # close any emacs sessions
trash /Applications/Emacs.app # trash old emacs
mv ${BUILD_DIR}/nextstep/Emacs.app /Applications # move build to applications folder

echo "DONE!"

echo "
# ======================================================
# Change icon
# ======================================================
"

cp ~/Pictures/emacs-icons/emacs-big-sur.icns /Applications/Emacs.app/Contents/Resources/Emacs.icns
cp ~/Pictures/emacs-icons/info.plist /Applications/Emacs.app/Contents/Info.plist

echo "DONE!"

echo "
# ======================================================
# Open new emacs
# ======================================================
"

open /Applications/Emacs.app

echo "DONE!"

echo "
# ======================================================
# Cleanup
# ======================================================
"

mkdir ${ROOT_DIR}/build-logs/${DESCR}
cp ${BUILD_DIR}/config.log ${ROOT_DIR}/build-logs/${DESCR}/${DESCR}-config.log
cp ${BUILD_DIR}/build-log.txt ${ROOT_DIR}/build-logs/${DESCR}/${DESCR}-build-log.txt
cp ${BUILD_DIR}/bootstrap-log.txt ${ROOT_DIR}/build-logs/${DESCR}/${DESCR}-bootstrap-log.txt


rm -rf ${BUILD_DIR}

echo "DONE!"