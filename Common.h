/*
 *  Common.h
 *  yarg
 *
 *  Created by Alex Pretzlav on 4/28/08.
 *  Copyright 2008 Alex Pretzlav. All rights reserved.
 *
 */

#ifndef _YARGCOMMON_H
#define _YARGCOMMON_H

#include "BetterAuthorizationSampleLib.h"

/*
 
 Commands passed between Yargcontroller and HelperTool
 to host priveledged rsync parties and write launchd 
 tasks to root's LaunchAgents.
 
*/
 

#define kRunRsyncCommand "RunRsync"
// inputs:
    // kBASCommandKey (CFString)
    // (CFString) -- arguments to pass to rsync binary
    #define kRsyncArgs "RsyncArgs"
// outputs:
    // kBASErrorKey (CFNumber)
    // kBASDescriptorArrayKey (CFArray of CFNumber) -- one entry, rsync's in/out pipe
    // (CFNumber) PID of the rsync task launched
    #define kRsyncPID "RsyncPID"
    // authorization right
    #define kRunRsyncCommandRightName "com.pretz.yarg.RunRsync"

#define kStopRsyncCommand "StopRsync"
// inputs:
// kBASCommandKey (CFString)
// kRsyncPID (CFNumber) PID of rsync to SIGTERM
// outputs:
// kBASErrorKey (CFNumber)
// kBASDescriptorArrayKey (CFArray of CFNumber) -- one entry, rsync's in/out pipe
// authorization right
#define kStopRsyncCommandRightName "com.pretz.yarg.StopRsync"

#define kWriteLaunchdJobCommand "WriteLaunchdJob"
// inputs:
    // kBASCommandKey (CFString)
    // (CFDictionary) -- Dictionary to write to file
    #define kLaunchdDictionary "LaunchdDictionary"
    // (CFString) -- name to give to dictionary file
    #define kNameOfDictionary "NameOfDict"
// outputs:
    // kBASErrorKey (CFNumber)
    // authorization right
    #define kWriteLauncdJobCommandRightName "com.pretz.yarg.WriteLaunchdJob"

extern const BASCommandSpec kYargCommandSet[];

#endif