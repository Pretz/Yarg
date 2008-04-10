#!/bin/sh

# package.sh
# yarg
#
# Created by Alex Pretzlav on 5/30/07.
# Copyright 2007 Alex Pretzlav. All rights reserved.

# to be run from the root directory containing the xcodeproj file

xcodebuild -configuration Release clean build
rm build/Release/syncer
cp LICENSE.txt build/Release/
cp README.rtf build/Release/
rm yarg.dmg
hdiutil create -srcfolder build/Release -format UDBZ -volname Yarg yarg.dmg
