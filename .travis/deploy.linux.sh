#!/bin/bash

if [ $# -lt 1 -o $# -gt 2 ]; then
  echo "Usage: $0 <output prefix> [<version for .deb and .rpm>]"
  exit 1
fi

export TRAVISDIR=$(cd "$(dirname "$0")"; pwd)
export ROOTDIR=$TRAVISDIR/..
export PREFIX=$1
export VERSION=$2

cd $ROOTDIR

##################### AppImage creation #####################

# Create a new dist folder
rm -rf dist
mkdir -p dist/opt/redtimer

# Include binary and dist files
cp gui/redtimer dist/opt/redtimer
cp cli/redtimercli dist/opt/redtimer
cp gui/icons/clock_red.svg dist/opt/redtimer/redtimer.svg
cp .travis/redtimer.desktop dist/opt/redtimer

# Include SVG icon engine
# @todo Integrate into deploylinuxqt
mkdir -p dist/opt/redtimer/plugins/iconengines
cp -a /opt/qt57/plugins/iconengines/libqsvgicon.so dist/opt/redtimer/plugins/iconengines

# First run
.travis/linuxdeployqt.AppImage dist/opt/redtimer/redtimer -qmldir=gui/qml -verbose=2
.travis/linuxdeployqt.AppImage dist/opt/redtimer/redtimercli -qmldir=gui/qml -verbose=2

# Stripping by linuxdeployqt does not satisfy lintian
strip dist/opt/redtimer/redtimer
strip dist/opt/redtimer/redtimercli

# Second run, to include xcbglintegration
.travis/linuxdeployqt.AppImage dist/opt/redtimer/redtimer -qmldir=gui/qml -appimage -bundle-non-qt-libs -verbose=2

mv dist/opt/redtimer.AppImage $PREFIX.AppImage

##################### DEB/RPM creation #####################

if [ -z "$VERSION" ]; then
  export VERSION="0.1-pre0"
  echo "Building dummy version $VERSION"
fi

mkdir -p dist/usr/bin
mkdir -p dist/usr/share/applications
mkdir -p dist/usr/share/icons/hicolor/scalable/apps

ln -sf /opt/redtimer/redtimer dist/usr/bin/redtimer
ln -sf /opt/redtimer/redtimercli dist/usr/bin/redtimercli
mv dist/opt/redtimer/redtimer.desktop dist/usr/share/applications
mv dist/opt/redtimer/redtimer.svg dist/usr/share/icons/hicolor/scalable/apps
rm -f dist/opt/redtimer/default.png

# Add Debian-specific files
export TIMESTAMP=$(date -R)
cat > CHANGELOG <<- END
redtimer ($VERSION) unstable; urgency=low

  * Dummy changelog to please lintian

 -- Frederick Thomssen <thomssen@thomssen-it.de>  $TIMESTAMP
END

mkdir -p dist/usr/share/doc/redtimer
cp $TRAVISDIR/debian/copyright dist/usr/share/doc/redtimer

# Set correct filesystem permissions
find dist/* -type d -exec chmod 755 {} \;
find dist/* -type f -exec chmod 644 {} \;
chmod 755 dist/opt/redtimer/redtimer
chmod 755 dist/opt/redtimer/redtimercli

export MAINT="Frederick Thomssen <thomssen@thomssen-it.de>"
export DESCR="Redmine Time Tracker\n\n
RedTimer is an easy-to-use platform-independent time tracker which allows the\n
user to track time while working on an issue. Furthermore, a user can create\n
new issues using RedTimer during which the time tracking will already start."

rm -f $PREFIX.deb $PREFIX.rpm

# .deb
fpm -s dir -t deb -p $PREFIX.deb -m "${MAINT}" --description "${DESCR}" -n redtimer -v ${VERSION} -C dist --category net --deb-no-default-config-files --deb-changelog CHANGELOG --no-depends

# .rpm
fpm -s dir -t rpm -p $PREFIX.rpm -m "${MAINT}" --description "${DESCR}" -n redtimer -v ${VERSION} -C dist --category net --deb-no-default-config-files
