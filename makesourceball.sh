#!/bin/sh

# makesourceball.sh
# yarg
#
# Created by Alex Pretzlav on 5/30/07.
# Copyright 2007 Alex Pretzlav. All rights reserved.

# run this script in the root project directory to make a source code tarball
xcodebuild -configuration Debug clean
xcodebuild -configuration Release clean
tar -vczf yargsource.tgz --exclude "*.DS_Store" --exclude "._*" --exclude "build/Release/*" \
 --exclude "build/Debug/*" --exclude "website/*.dmg" --exclude "website/*.tgz" \
 --exclude yargsource.tgz --exclude ".svn" --exclude "./*.dmg" .
