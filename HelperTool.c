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
#include <sys/stat.h>
#include <CoreServices/CoreServices.h>
#include "BetterAuthorizationSampleLib.h"

#include "Common.h"

#define RSYNC_BUF_LEN 4096
#define kSmallBuff 1024
#define RSYNC_PATH "/usr/bin/rsync"
#define PID_FILE "/tmp/com.pretz.yarg.pid"
#define kBackupPlistPath "/Library/LaunchAgents/"
#define kDictSizeLimit (1024 * 1024)
#define kLaunchdFileFlags O_RDWR | O_CREAT | O_TRUNC | O_NOFOLLOW
#define kLaunchdFilePerms S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH

/************************  :-)  ******************   )-:  ************/

#pragma mark Helper Functions

static Boolean saveRsyncPid(pid_t pid) {
    FILE *tmp_file;
    Boolean result;
    tmp_file = fopen(PID_FILE, "w");
    fchmod(fileno(tmp_file), S_IRUSR | S_IWUSR);
    if (tmp_file == NULL)
        return false;
    if (fprintf(tmp_file, "%d\n", (int) pid) > 0) {
        result = false;
    } else {
        result = true;
    }
    fclose(tmp_file);
    return result;
}

static pid_t recoverRsyncPid() {
    FILE *tmp_file;
    int recovered_pid;
    tmp_file = fopen(PID_FILE, "r");
    if (tmp_file == NULL)
        return 0;
    if (fscanf(tmp_file, "%d", &recovered_pid) <= 0) {
        recovered_pid = 0;
    }
    fclose(tmp_file);
    return recovered_pid;
    
}

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
    /*
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "length of string: %d", CFStringGetLength(rsyncPath));
    */
    CFStringAppend(rsyncPath, CFSTR(" "));
    
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
    saveRsyncPid(child_pid);
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

    rpid = recoverRsyncPid();
    if (rpid == 0)
        return -1;
    kill(rpid, SIGTERM);
    return noErr;
}

#pragma mark Write Launchd Job Command

static int writeDictionaryToDescriptor(CFDictionaryRef dict, int fdOut) {
    // Adapted from BASWriteDictionary() and BASWrite()
    
    int                 err = 0;
	CFDataRef			dictData;
    char *	cursor;
	size_t	bytesLeft;
	ssize_t bytesThisTime;
    
    // Pre-conditions
    
	assert(dict != NULL);
	assert(fdOut >= 0);
	
	dictData   = NULL;
    
    // Get the dictionary as XML data.
    
	dictData = CFPropertyListCreateXMLData(NULL, dict);
	if (dictData == NULL) {
		err = ENOMEM;
	}
    
    // Send the length, then send the data.  Always send the length as a big-endian 
    // uint32_t, so that the app and the helper tool can be different architectures.
    //
    // The MoreAuthSample version of this code erroneously assumed that CFDataGetBytePtr 
    // can fail and thus allocated an extra buffer to copy the data into.  In reality, 
    // CFDataGetBytePtr can't fail, so this version of the code doesn't do the unnecessary 
    // allocation.
    
    if ( (err == 0) && ((bytesLeft = CFDataGetLength(dictData)) > kDictSizeLimit) ) {
        err = EINVAL;
    }
	if (err == 0) {
        cursor = (char *) CFDataGetBytePtr(dictData);
        while (err == 0 && bytesLeft != 0) {
            bytesThisTime = write(fdOut, cursor, bytesLeft);
            if (bytesThisTime > 0) {
                cursor    += bytesThisTime;
                bytesLeft -= bytesThisTime;
            } else if (bytesThisTime == 0) {
                err = EIO;
            } else {
                assert(bytesThisTime == -1);
                err = errno;
                if (err == EINTR) {
                    err = 0;		// let's loop again
                }
            }
        }
	}
    
	if (dictData != NULL) {
		CFRelease(dictData);
	}
    
	return err;
    
}

static int informLaunchd(char * command, char * plistName) {
    int				err;
	const char *	args[4];
	pid_t			childPID;
	pid_t			waitResult;
	int				status;
    char  plistPath[kSmallBuff];
    
    strncpy(plistPath, kBackupPlistPath, kSmallBuff);
    strncat(plistPath, plistName, kSmallBuff - strlen(kBackupPlistPath) -1);
	
	// Pre-conditions.
    if (command == NULL || plistPath == NULL ||
        (strncmp("load", command, 5) != 0 &&
         strncmp("unload", command, 7) != 0)) {
        return EINVAL;
    }
    
    args[0] = "/bin/launchctl";
    args[1] = command;
    args[2] = plistPath;
    args[3] = NULL;
    
    fprintf(stderr, "%s %s '%s' \n", args[0], args[1], args[2]);
    
    childPID = fork();
    switch (childPID) {
        case 0:
            err = execv(args[0], (char **) args);
            if (err < 0) {
                exit(errno);
            }
            break;
        case -1:
            err = errno;
            break;
        default:
            err = 0;
            break;
    }
    /* Parent */
    if (err == 0) {
        do {
			waitResult = waitpid(childPID, &status, 0);
		} while ( (waitResult == -1) && (errno == EINTR) );
/*        
		if (waitResult < 0) {
			err = errno;
		} else {
			assert(waitResult == childPID);
            
            if ( ! WIFEXITED(status) || (WEXITSTATUS(status) != 0) ) {
                err = EINVAL;
            }
		} */
    }
    
    return err;
}

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
    CFDictionaryRef launchdJob;
    CFStringRef rsyncPath;
    CFStringRef launchdFileName;
    CFMutableStringRef fullPathToPlist;
    UInt8 fullPathToPlistCString[RSYNC_BUF_LEN];
    UInt8 nameOfPlist[kSmallBuff];
    int fdForPlist;
    CFRange range;
    range.location = 0;
    
    launchdJob = CFDictionaryGetValue(request, CFSTR(kLaunchdDictionary));
    if (launchdJob == NULL)
        return -1;
    /* Validate args */
    rsyncPath = CFDictionaryGetValue(launchdJob, CFSTR("Program"));
    if (CFStringCompare(rsyncPath, CFSTR(RSYNC_PATH), 0) != kCFCompareEqualTo) {
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Tried to write launchd job that doesn't run rsync");
        return -1;
    }
    
    if ((launchdFileName = CFDictionaryGetValue(request, CFSTR(kNameOfDictionary))) == NULL) {
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Request didn't contain dest filename for launchd job");
        return -1;
    }
    if ((fullPathToPlist = CFStringCreateMutableCopy(NULL, 0, CFSTR(kBackupPlistPath))) == NULL) {
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Memory error");
        return -1;
    }
    CFStringAppend(fullPathToPlist, launchdFileName);
    
    range.length = CFStringGetLength(fullPathToPlist);
    CFStringGetBytes(fullPathToPlist, range,
                     kCFStringEncodingUTF8, 0, FALSE, fullPathToPlistCString, RSYNC_BUF_LEN, NULL);
    fullPathToPlistCString[range.length] = '\0';
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Going to write plist to %s", fullPathToPlistCString);
    
    fdForPlist = open((char *)fullPathToPlistCString, kLaunchdFileFlags, kLaunchdFilePerms);
    if (fdForPlist <= 0) {
        retval = errno;
    }
    if (retval == noErr) {
        /* Still must chmod file in case it already exists */
        fchmod(fdForPlist, kLaunchdFilePerms);
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Descriptor of plist: %d", fdForPlist);
    }
    if ( retval == noErr &&
        (retval = writeDictionaryToDescriptor(launchdJob, fdForPlist)) != noErr) {
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Failed to write plist file");
    }
    
    CFRelease(fullPathToPlist);
    if (retval == noErr) {
        /* Tell launchd about job */
        range.length = CFStringGetLength(launchdFileName);
        CFStringGetBytes(launchdFileName, range,
                         kCFStringEncodingUTF8, 0, FALSE, nameOfPlist, kSmallBuff, NULL);
        nameOfPlist[range.length] = '\0';
        
        retval = informLaunchd("unload", (char *) nameOfPlist);
        retval = informLaunchd("load", (char *) nameOfPlist);
    }

    
    return retval;
}

#pragma mark Delete Launchd Job Command

static OSStatus DoDeleteLaunchdJob(
    AuthorizationRef			auth,
    const void *                userData,
    CFDictionaryRef			    request,
    CFMutableDictionaryRef      response,
    aslclient                   asl,
    aslmsg                      aslMsg
)
// Implements the kDeleteLaunchdJobCommand.  Returns noErr on success.
{
    OSStatus retval = noErr;
    CFStringRef plistName;
    char pathToPlist[kSmallBuff];
    CFRange range;
    int pathLen;
    range.location = 0;
    
    asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Beginning DoDeleteLaunchdJob");
    
    if ((plistName = CFDictionaryGetValue(request, CFSTR(kNameOfDictionary))) == NULL) {
        retval = EINVAL;
        asl_log(asl, aslMsg, ASL_LEVEL_ERR, "Couldn't get plist out of query");
    }
    
    range.length = CFStringGetLength(plistName);
    if (range.length > kSmallBuff) {
        retval = EINVAL;
    }
    
    if (retval == noErr) {
        /* pathToPlist isn't a path here, it's just a filename */
        CFStringGetBytes(plistName, range,
                         kCFStringEncodingUTF8, 0, FALSE, (UInt8 *) pathToPlist, kSmallBuff, NULL);
        pathToPlist[range.length] = '\0';
        retval = informLaunchd("unload", pathToPlist);
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Informed launchd to unload %s and heard %d.", pathToPlist, retval);
    }
    
    if (retval == noErr) {
        pathLen = strlen(kBackupPlistPath);
        strncpy(pathToPlist, kBackupPlistPath, pathLen);
        range.length = CFStringGetLength(plistName);
        CFStringGetBytes(plistName, range,
                         kCFStringEncodingUTF8, 0, FALSE, (UInt8 *) pathToPlist+pathLen, kSmallBuff-pathLen, NULL);
        pathToPlist[range.length+pathLen] = '\0';
        asl_log(asl, aslMsg, ASL_LEVEL_DEBUG, "Unlinking %s", pathToPlist);
        retval = unlink(pathToPlist);
        if (retval < 0) {
            retval = errno;
        }
    }
    
    return retval;
    
}

#pragma mark BAS Infrastructure

static const BASCommandProc kYargCommandProcs[] = {
    DoRunRsync,
    DoStopRsync,
    DoWriteLaunchdJob,
    DoDeleteLaunchdJob,
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