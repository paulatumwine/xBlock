#!/usr/bin/env bash
#
# This script assumes a linux environment

set -e

echo "*** uBOLite.mv3: Creating extension"

PLATFORM="chromium"

for i in "$@"; do
  case $i in
    quick)
      QUICK="yes"
      shift # past argument=value
      ;;
    full)
      FULL="yes"
      shift # past argument=value
      ;;
    firefox)
      PLATFORM="firefox"
      shift # past argument=value
      ;;
    chromium)
      PLATFORM="chromium"
      shift # past argument=value
      ;;
  esac
done

DES="dist/build/uBOLite.$PLATFORM"

if [ "$QUICK" != "yes" ]; then
    rm -rf $DES
fi

mkdir -p $DES
cd $DES
DES=$(pwd)
cd - > /dev/null

mkdir -p $DES/css/fonts
mkdir -p $DES/js
mkdir -p $DES/img

if [ "$UBO_VERSION" != "local" ]; then
    UBO_VERSION=$(cat platform/mv3/ubo-version)
    UBO_REPO="https://github.com/gorhill/uBlock.git"
    UBO_DIR=$(mktemp -d)
    echo "*** uBOLite.mv3: Fetching uBO $UBO_VERSION from $UBO_REPO into $UBO_DIR"
    git clone -q --depth 1 --branch "$UBO_VERSION" "$UBO_REPO" "$UBO_DIR"
else
    UBO_DIR=.
fi

echo "*** uBOLite.mv3: Copying common files"
cp -R $UBO_DIR/src/css/fonts/* $DES/css/fonts/
cp $UBO_DIR/src/css/themes/default.css $DES/css/
cp $UBO_DIR/src/css/common.css $DES/css/
cp $UBO_DIR/src/css/dashboard-common.css $DES/css/
cp $UBO_DIR/src/css/fa-icons.css $DES/css/

cp $UBO_DIR/src/js/dom.js $DES/js/
cp $UBO_DIR/src/js/fa-icons.js $DES/js/
cp $UBO_DIR/src/js/i18n.js $DES/js/
cp $UBO_DIR/src/lib/punycode.js $DES/js/

cp -R $UBO_DIR/src/img/flags-of-the-world $DES/img

cp LICENSE.txt $DES/

echo "*** uBOLite.mv3: Copying mv3-specific files"
if [ "$PLATFORM" = "firefox" ]; then
    cp platform/mv3/firefox/background.html $DES/
fi
cp platform/mv3/extension/*.html $DES/
cp platform/mv3/extension/*.json $DES/
cp platform/mv3/extension/css/* $DES/css/
cp -R platform/mv3/extension/js/* $DES/js/
cp platform/mv3/extension/img/* $DES/img/
cp -R platform/mv3/extension/_locales $DES/
cp platform/mv3/README.md $DES/

if [ "$QUICK" != "yes" ]; then
    echo "*** uBOLite.mv3: Generating rulesets"
    TMPDIR=$(mktemp -d)
    mkdir -p $TMPDIR
    if [ "$PLATFORM" = "chromium" ]; then
        cp platform/mv3/chromium/manifest.json $DES/
    elif [ "$PLATFORM" = "firefox" ]; then
        cp platform/mv3/firefox/manifest.json $DES/
    fi
    ./tools/make-nodejs.sh $TMPDIR
    cp platform/mv3/package.json $TMPDIR/
    cp platform/mv3/*.js $TMPDIR/
    cp platform/mv3/extension/js/utils.js $TMPDIR/js/
    cp $UBO_DIR/assets/assets.json $TMPDIR/
    cp $UBO_DIR/assets/resources/scriptlets.js $TMPDIR/
    cp -R platform/mv3/scriptlets $TMPDIR/
    mkdir -p $TMPDIR/web_accessible_resources
    cp $UBO_DIR/src/web_accessible_resources/* $TMPDIR/web_accessible_resources/
    cd $TMPDIR
    node --no-warnings make-rulesets.js output=$DES platform="$PLATFORM"
    cd - > /dev/null
    rm -rf $TMPDIR
fi

echo "*** uBOLite.mv3: extension ready"
echo "Extension location: $DES/"

if [ "$FULL" = "yes" ]; then
    EXTENSION="zip"
    if [ "$PLATFORM" = "firefox" ]; then
        EXTENSION="xpi"
    fi
    echo "*** uBOLite.mv3: Creating publishable package..."
    PACKAGENAME="uBOLite_$(jq -r .version $DES/manifest.json).$PLATFORM.mv3.$EXTENSION"
    TMPDIR=$(mktemp -d)
    mkdir -p $TMPDIR
    cp -R $DES/* $TMPDIR/
    cd $TMPDIR > /dev/null
    zip $PACKAGENAME -qr ./*
    cd - > /dev/null
    cp $TMPDIR/$PACKAGENAME dist/build/
    rm -rf $TMPDIR
    echo "Package location: $(pwd)/dist/build/$PACKAGENAME"
fi
