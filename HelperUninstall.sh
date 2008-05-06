#! /bin/sh

# This uninstalls everything installed by BAS.

BUNDLE_NAME=com.pretz.yarg

sudo launchctl unload -w /Library/LaunchDaemons/${BUNDLE_NAME}.plist
sudo rm /Library/LaunchDaemons/${BUNDLE_NAME}.plist
sudo rm /Library/PrivilegedHelperTools/${BUNDLE_NAME}
sudo rm /var/run/${BUNDLE_NAME}.socket
