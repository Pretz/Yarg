#!/bin/sh

# package.sh
# yarg
#
# Created by Alex Pretzlav on 5/30/07. Last updated 5/16/2008.
# Copyright 2008 Alex Pretzlav. All rights reserved.

# to be run from the root directory containing the xcodeproj file

PACKDIR=package
APP=Yarg

xcodebuild -configuration Release clean build
mkdir $PACKDIR
cp -r build/Release/${APP}.app $PACKDIR/
cp LICENSE.txt $PACKDIR/
cp README.rtf $PACKDIR/
rm ${APP}.dmg
echo "Generating dmg, takes a bit..."
hdiutil create -srcfolder $PACKDIR -format UDBZ -volname $APP ${APP}.dmg
rm -rf $PACKDIR
chmod a+r ${APP}.dmg