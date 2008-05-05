/*
 *  HelperTool.c
 *  yarg
 *
 *  Created by Alex Pretzlav on 4/28/08.
 *  Copyright 2008 Alex Pretzlav. All rights reserved.
 *
 */
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <CoreServices/CoreServices.h>
#include "BetterAuthorizationSampleLib.h"

#include "Common.h"

#define RSYNC_BUF_LEN 4096
#define RSYNC_PATH "/usr/bin/rsync "

/************************  :-)  ******************   )-:  ************/

pid_t gRsyncPID = 0;

#pragma mark Run Rsync Command

/*!
 *  Forks a new process and executes rsync in that process.  Returns a file descriptor
 *  representing the stdout of rsync, and assigns pid to the pid of the rsync process.
 */
static int ForkAndRunRsync(const char *args, pid_t *pid, aslclient asl, aslmsg aslMsg) {
    int child_pid;
    int rsyncPipe[2];
    char * shArgs[] = {
        "sh", "-c", NULL, NULL
    };
    if (pipe(rsyncPipe) != 0) {
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to create pipe for rsync.");
        return -1;
    }
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Created pipe, forking.");
    child_pid = fork();
    if (child_pid == 0) { /* Child */
        /*        int stdout2 = fileno(stdout);
         if (close(stdout2) != 0) {
         asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to close rsync fork stdout: %d.", errno);
         exit(-1);
         }*/
        if (dup2(rsyncPipe[1], STDOUT_FILENO) < 0) {
            asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to dup2 pipe for rsync's stdout: %d.", errno);
            exit(-1);
        }
        close(rsyncPipe[0]);
        if (close(rsyncPipe[1]) != 0) {
            asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to close rsyncOutPipe[1].");
            exit(-1);
        }
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Will exec rsync with the following: %s", args);
        shArgs[2] = (char *) args;
        /* Try to run rsync in a new session so launchd doesn't reap it */
        setsid();
        execv("/bin/sh", shArgs); /* Never returns */
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to exec rsync!");
        exit(-1);
    } else if (child_pid < 0) { /* Error */
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to fork child.");
        return -1;
    }
    *pid = child_pid;
    close(rsyncPipe[1]);
    return rsyncPipe[0];
}

static OSStatus DoRunRsync(
    AuthorizationRef			auth,
    const void *                userData,
    CFDictionaryRef			    request,
    CFMutableDictionaryRef      response,
    aslclient                   asl,
    aslmsg                      aslMsg
)
// Implements the kRunRsyncCommand.  Returns the file descriptor
// of rsync's output while running.
{	
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "HelperTool beginning rsync job.");
    OSStatus retval = noErr;
    UInt8 rsyncArgsBuff[RSYNC_BUF_LEN];
    pid_t child_pid;
    int rsyncOutDesc;
    CFMutableStringRef rsyncPath;
    CFStringRef args;
    CFNumberRef descNum;
    CFMutableArrayRef descArray;
    CFRange range;
    range.location = 0;
    
    /* Get args from request */
    args = CFDictionaryGetValue(request, CFSTR(kRsyncArgs));
    if (args == NULL) {
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "rsync args null.");
        return -1;
    }

    rsyncPath = CFStringCreateMutableCopy(NULL, RSYNC_BUF_LEN, CFSTR(RSYNC_PATH));
    if (rsyncPath == NULL) {
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "CFStringCreateMutableCopy failed");
        return -1;
    }
    
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "length of string: %d", CFStringGetLength(rsyncPath));
    
    CFStringAppend(rsyncPath, args);

    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "About to get bytes of rsyncArgs.");

    range.length = CFStringGetLength(rsyncPath);
    /* Copy the full arguments to sh into rsyncArgsBuff */ 
    CFStringGetBytes(rsyncPath, range,
                     kCFStringEncodingUTF8, 0, FALSE, rsyncArgsBuff, RSYNC_BUF_LEN, NULL);
    CFRelease(rsyncPath);
    
    /* Looks like CFStringGetBytes doesn't null-terminate */
    rsyncArgsBuff[range.length] = '\0';
   
    rsyncOutDesc = ForkAndRunRsync((char *)rsyncArgsBuff, &child_pid, asl, aslMsg);
    if (rsyncOutDesc < 0) {
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Couldn't invoke rsync.");
        return -1;
    }
    gRsyncPID = child_pid;
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Returning descriptor for rsync.");
    descNum = CFNumberCreate(NULL, kCFNumberIntType, &rsyncOutDesc);
    descArray = CFArrayCreateMutable(NULL, 1, &kCFTypeArrayCallBacks);
    CFArrayAppendValue(descArray, descNum);
    CFRelease(descNum);
    CFDictionaryAddValue(response, CFSTR(kBASDescriptorArrayKey), descArray);
    CFRelease(descArray);
    descNum = CFNumberCreate(NULL, kCFNumberIntType, &child_pid);
    CFDictionaryAddValue(response, CFSTR(kRsyncPID), descNum);
    CFRelease(descNum);
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Closing pipe input in parent.");
    return retval;
}

#pragma mark Stop Rsync Command

static OSStatus DoStopRsync(
    AuthorizationRef			auth,
    const void *                userData,
    CFDictionaryRef			    request,
    CFMutableDictionaryRef      response,
    aslclient                   asl,
    aslmsg                      aslMsg
)
// Implements the kStopRsyncCommand.  If gRsyncPID is not 0, sends SIGTERM to that PID,
// otherwise sends SIGTERM to the PID specified in request[kRsyncPID]
{
    pid_t rpid;
    CFNumberRef rpidNum;
    rpid = gRsyncPID;
    if (rpid != 0) {
        kill(rpid, SIGTERM);
        return noErr;
    }
    rpidNum = CFDictionaryGetValue(request, CFSTR(kRsyncPID));
    if (rpidNum == NULL)
        return -1;
    if (CFNumberGetValue(rpidNum, kCFNumberIntType, &rpid) == false)
        return -1;
    kill(rpid, SIGTERM);
    return noErr;
}

#pragma mark Write Launchd Job Command

static OSStatus DoWriteLaunchdJob(
    AuthorizationRef			auth,
    const void *                userData,
    CFDictionaryRef			    request,
    CFMutableDictionaryRef      response,
    aslclient                   asl,
    aslmsg                      aslMsg
)
// Implements the kWriteLaunchdJobCommand.  Returns noErr on success.
{	
    OSStatus retval = noErr;

    return retval;
}

#pragma mark BAS Infrastructure

static const BASCommandProc kYargCommandProcs[] = {
    DoRunRsync,
    DoStopRsync,
    DoWriteLaunchdJob,
    NULL
};

int main(int argc, char **argv)
{
    // Go directly into BetterAuthorizationSampleLib code.
	
    // IMPORTANT
    // BASHelperToolMain doesn't clean up after itself, so once it returns 
    // we must quit.
    
	return BASHelperToolMain(kYargCommandSet, kYargCommandProcs);
}