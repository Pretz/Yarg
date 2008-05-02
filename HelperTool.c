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
#include <CoreServices/CoreServices.h>
#include "BetterAuthorizationSampleLib.h"

#include "Common.h"

#define RSYNC_BUF_LEN 4096

/************************  :-)  ******************   )-:  ************/


pid_t gRsyncPID = 0;

#pragma mark Run Rsync Command

static int ForkAndRunRsync(const char *args, pid_t *pid) {
    return 0;
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
    int rsyncOutPipe[2];
    pid_t fork_pid;
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "0");
    char * shArgs[] = {
        "sh", "-c", NULL, NULL
    };
    CFIndex numchars;
    CFMutableStringRef rsyncPath;
    CFStringRef args;
    CFNumberRef descNum;
    CFMutableArrayRef descArray;
    CFRange range;
    range.location = 0;
    
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "euid=%ld, ruid=%ld", (long) geteuid(), (long) getuid());
    
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "1.");
    args = CFDictionaryGetValue(request, CFSTR(kRsyncArgs));
    if (args == NULL) {
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "rsync args null.");
        return -1;
    }
    else {
        range.length = CFStringGetLength(args);
        CFStringGetBytes(args, range,
                         kCFStringEncodingUTF8, 0, FALSE, rsyncArgsBuff, RSYNC_BUF_LEN, NULL);
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Got rsync args: %s", rsyncArgsBuff);
    }
//    CFShowStr(args);
    rsyncPath = CFStringCreateMutableCopy(kCFAllocatorDefault, RSYNC_BUF_LEN, CFSTR("/usr/bin/rsync "));
    if (rsyncPath == NULL) {
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "CFStringCreateMutableCopy failed");
        return -1;
    }
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "didn't bus error after create mutable copy");
    range.length = CFStringGetLength(rsyncPath);
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "length of string: %d", range.length);
    numchars = CFStringGetBytes(rsyncPath, range,
                     kCFStringEncodingUTF8, 0, FALSE, rsyncArgsBuff, RSYNC_BUF_LEN, NULL);
    if (numchars == 0) {
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Getting string bytes failed.");
        return -1;
    } else
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Getting bytes succeeded.");
    rsyncArgsBuff[range.length] = '\0';
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Created mutable string: %s, length %d", 
                rsyncArgsBuff, numchars);
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "didn't bus error after printing string");
    CFStringAppend(rsyncPath, args);
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "3");
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "About to get bytes of rsyncArgs.");
    range.length = CFStringGetLength(rsyncPath);
    CFStringGetBytes(rsyncPath, range,
                     kCFStringEncodingUTF8, 0, FALSE, rsyncArgsBuff, RSYNC_BUF_LEN, NULL);
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Will exec rsync with the following: %s", rsyncArgsBuff);
    if (pipe(rsyncOutPipe) != 0) {
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to create pipe for rsync.");
        return -1;
    }
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Created pipe, forking.");
    fork_pid = fork();
    if (fork_pid == 0) { /* Child */
/*        int stdout2 = fileno(stdout);
        if (close(stdout2) != 0) {
            asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to close rsync fork stdout: %d.", errno);
            exit(-1);
        }*/
        if (dup2(rsyncOutPipe[1], STDOUT_FILENO) < 0) {
            asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to dup2 pipe for rsync's stdout: %d.", errno);
            exit(-1);
        }
        close(rsyncOutPipe[0]);
        if (close(rsyncOutPipe[1]) != 0) {
            asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to close rsyncOutPipe[1].");
            exit(-1);
        }
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Exec'ing rsync.");
        shArgs[2] = (char *)rsyncArgsBuff;
        execv("/bin/sh", shArgs); /* Never returns */
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to exec rsync!");
        exit(-1);
    } else if (fork_pid < 0) { /* Error */
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to fork child.");
        return -1;
    }
    gRsyncPID = fork_pid;
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Returning descriptor for rsync.");
    descNum = CFNumberCreate(NULL, kCFNumberIntType, &(rsyncOutPipe[0]));
    descArray = CFArrayCreateMutable(NULL, 1, &kCFTypeArrayCallBacks);
    CFArrayAppendValue(descArray, descNum);
    CFDictionaryAddValue(response, CFSTR(kBASDescriptorArrayKey), descArray);
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Closing pipe input in parent.");
    close(rsyncOutPipe[1]);
    return retval;
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