/*  Copyright 2006-2007 Alex Pretzlav. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

*/

#include <sys/types.h>
#include <unistd.h>

#import "YargController.h"
#import "Job.h"
#import "additions.h"

#import "Common.h"

extern AuthorizationRef gAuth;

// Internal functions I only want to use within YargController
@interface YargController (private)
- (void)shrinkBackupWindow;
- (void)growBackupWindow;
- (Job *)activeJob;
- (void)resizeForAdvancedOrBasic:(int)amountToChange animate:(BOOL)bl; 
- (void)informLaunchd:(Job *) job;
- (void)runJobInNewThread:(id)sender;
- (void)setTabView:(NSTabView *)tabView Enabled:(BOOL)yesno;
- (void)setProgressForOutput:(NSString *)line;
@end


@implementation YargController 

#pragma mark IBAction GUI Functions

/*******    IBAction functions called from GUI user interaction    ********
********/

- (IBAction)deleteJob:(id)sender
{
	Job * job = [self activeJob];
	if (! [job deleteLaunchdPlist]) {
		NSBeginCriticalAlertSheet(@"Critical Error!" , @"Okay", 
								  nil, 
								  nil, 
								  mainView, 
								  self, 
								  NULL, 
								  NULL, 
								  NULL,							 
								  [NSString stringWithFormat:@"Job cannot be deleted!\n Is %@ writeable?", [job pathToPlist]]);
		return;
	}
	[jobsDictionary removeObjectForKey:[job jobName]];
	[jobList removeObject:job];
	[self synchronizeSettingsToDisk:nil];
}

- (IBAction)modifyJob:(id)sender
{
	modifying = YES;
	[self editSelectedJob];
}

- (IBAction)newJob:(id)sender
{
	NSAssert([jobsDictionary isKindOfClass:[NSMutableDictionary class]] == YES, @"jobsDictionary is not an NSMutableDictionary");
	modifying = NO;
	Job * job = [[Job alloc] initWithPathFrom:@"" pathTo:@"" jobName:@""];
	[jobList addObject: [job autorelease]];
	[windowList reloadData];
	[jobList setSelectedObjects: [NSArray arrayWithObject: job]];
	[self editSelectedJob];
}

// TODO: This function is getting rather convoluted and hard to read.
- (IBAction)saveJob:(id)sender
{
	Job *job = [self activeJob];
	// Strip any spaces or tabs from beginning and end of jobName and paths:
	NSString * strippedJobName = [[jobName stringValue] stringByTrimmingWhitespace];
	NSString * strippedPathTo = [[pathTo stringValue] stringByTrimmingWhitespace];
	NSString * strippedPathFrom = [[pathFrom stringValue] stringByTrimmingWhitespace];
	// Check for invalid user entries:
	if ([strippedJobName isEqualToString: @""]) {
		[self freakoutAlertTitle:@"You need a name!" Text: @"Please give your backup job a name."];
		return;
	}
	if ([strippedPathTo isEqualToString: @""]) {
		[self freakoutAlertTitle:@"Invalid Path" Text:[NSString stringWithFormat:@"\"%@\" is not a valid path. "
			@"Please select a valid path.", strippedPathTo]];
		return;
	}
	if ([strippedPathFrom isEqualToString: @""]) {
		[self freakoutAlertTitle:@"Invalid Path" Text: [NSString stringWithFormat:@"\"%@\" is not a valid path. "
			@"Please select a valid path.", strippedPathFrom]];
		return;
	}
	// Set our job's data based on advanced check boxes
	[job setDeleteChanged: [deleteRemote state] == NSOnState ? YES : NO];
	[job setCopyHidden: [copyHidden state] == NSOnState ? YES : NO];
	[job setCopyExtended: [copyExtended state] == NSOnState ? YES : NO];
    [job setRunAsRoot: [runAsRootCheckbox state] == NSOnState ? YES : NO];
	// Make sure no other jobs have the same name (not including whitespace)
	NSString * errorFormat = @"You already have a job named \"%@\", not counting case or punctuation. "
	@"Please give your job a different name.";
	NSEnumerator *jobEnum = [[jobList content] objectEnumerator];
	Job *currentJob;
	while((currentJob = [jobEnum nextObject])) {
		// I think this shows where ObjC's syntax gets nasty; is there a nicer way to write this?
		if ([[[jobName stringValue] stringWithoutSpaces] caseInsensitiveCompare:
			[[currentJob jobName] stringWithoutSpaces]] == NSOrderedSame && currentJob != [self activeJob]) {
			[self freakoutAlertTitle:@"Name Collision" Text: 
				[NSString stringWithFormat: errorFormat, [currentJob jobName]]];
			return;
		}
	}
	/* If we're modifying jobName, gotta make sure to remove old job (which is keyed off of jobName)
		from defaults. */
	if (modifying && (![strippedJobName isEqualToString:[job jobName]])) {
		[jobsDictionary removeObjectForKey:[job jobName]];
	}
	smartLog(@"saving job called %@", strippedJobName);
	[job setJobName: strippedJobName];
	[job setPathFrom: strippedPathFrom];
	[job setPathTo: strippedPathTo];
	//[job setExcludeList:[[filesToIgnore string] componentsSeparatedByString:@" "]];
	[job setExcludeList:[[filesToIgnore string] componentsSeparatedByCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
	if ([scheduleCheckbox state] == NSOnState) {
        int selectedTab = [optBox indexOfTabViewItem:[optBox selectedTabViewItem]];
        [job setScheduleStyle: selectedTab == 0 ? ScheduleMonthly : ScheduleWeekly];
        NSCalendarDate *date;
        if (selectedTab == 0) {
            date = [[timeMonthInput dateValue] dateWithCalendarFormat:nil timeZone:nil];
            [job setDaysToRun:[NSArray arrayWithObject:[NSNumber numberWithInt:[dayOfMonthPopup indexOfSelectedItem] + 1]]];
        } else if (selectedTab == 1) {
            NSEnumerator * selectedCells = [[dayOfWeekChooser cells] objectEnumerator];
            NSMutableArray * daysToRun = [NSMutableArray arrayWithCapacity:7];
            NSButtonCell *nextCell;
            while((nextCell = [selectedCells nextObject])) {
                if ([nextCell state] == NSOnState)
                    [daysToRun addObject:[NSNumber numberWithInt:[nextCell tag]]];
            }
            [job setDaysToRun:daysToRun];
            date = [[timeWeekInput dateValue] dateWithCalendarFormat:nil timeZone:nil];
        }
        [job setTimeOfJob:[[NSCalendar currentCalendar] components:NSHourCalendarUnit | NSMinuteCalendarUnit
                                                          fromDate:date]];
	} else {
        [job setScheduleStyle:ScheduleNone];
    }
	modifying = NO;
	smartLog(@"%@", [job asLaunchdPlistDictionary]);
	if (! [job writeLaunchdPlist]) {
		[self freakoutAlertTitle:@"Critical Error!" 
							Text:[NSString stringWithFormat:@"Job cannot be saved!\n Is %@ writeable?", [job pathToPlist]]];
		return;
	}
	[self informLaunchd:job];
	[jobsDictionary setObject:[job asSerializedDictionary] forKey:[job jobName]];
	[self synchronizeSettingsToDisk:nil];
	[self dismissJobEditSheet];
}

- (IBAction)runJob:(id)sender
{
	[sender setEnabled:NO];
	[spinner startAnimation:self];
    [spinner setUsesThreadedAnimation:YES];
    [fileProgress setUsesThreadedAnimation:YES];
    [spinner setIndeterminate:YES];
    [spinner startAnimation:self];
    [NSApp beginSheet: backupRunningPanel
	   modalForWindow: mainView
		modalDelegate: self
	   didEndSelector: NULL
		  contextInfo: NULL];
	[backupRunningPanel makeKeyAndOrderFront:self];
    [filenamePrompt setStringValue:@""];
    [copyingFileName setStringValue:@""];
	Job * job = [self activeJob];
    if (! [job runAsRoot]) {
        rsyncTask = [[NSTask alloc] init];
        [rsyncTask setLaunchPath:[job rsyncPath]];
        [rsyncTask setArguments:[[job rsyncArguments] arrayByAddingObject:@"--no-detach"]];
        smartLog(@"rsync args: %@", [job rsyncArguments]);
    }
    NSArray * arguments = [NSArray arrayWithObjects:sender, nil];
    [NSThread detachNewThreadSelector:@selector(runJobInNewThread:) toTarget:self withObject:arguments];	
    
	/* Must make sure that rsync runs in the same group as this thread, so that when this thread dies,
		i.e. via force quit or something, rsync will be killed as well.
		from http://www.cocoadev.com/index.pl?NSTaskTermination
	// create a new group session with us as the leader, or failing that get our current group session
	processGroup = setsid();
	smartLog(@"try one group is %d", processGroup);
	if (processGroup == -1) {
		processGroup = getpgrp();
		smartLog(@"try two group is %d", processGroup);
	}
	smartLog(@"starting session id of rsync is %d", getpgid([rsyncTask processIdentifier]));
	// place into same group, this ensures that when yarg terminates rsync will terminate
	if ((getpgid([rsyncTask processIdentifier]) != processGroup) && (setpgid([rsyncTask processIdentifier], processGroup) == -1)) {
		NSLog(@"unable to put rsync into same group as self, error #: %d", errno);
		[rsyncTask terminate];
		[rsyncTask waitUntilExit];
	} else { */
    // Is it bad practice to call a method in this same object in a new thread, or just dangerous
    // because of data synchronicity?
//	}
	
	// is it better to have a notification receiver recieve when that thread exits rather than
	// having the thread clean up stuff started in this method?
}

- (void)runJobInNewThread:(id)arguments  
{
	// Creating the autorelease pool MUST be first thing in this method:
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[arguments retain];
    NSFileHandle * rsyncOutput;
    OSStatus commandErr;
    int rsyncOutDescriptor;
    if ([[self activeJob] runAsRoot]) {
        // LAUNCH BetterAuthSample HELPER TOOL
        OSStatus ipcErr;
        OSStatus        installErr;
        NSDictionary *  request;
        NSDictionary * response;
        BASFailCode     failCode;
        
        response = NULL;
        request = [NSDictionary 
                   dictionaryWithObjectsAndKeys:
                   @kRunRsyncCommand, 
                   @kBASCommandKey,
                   [[[self activeJob] rsyncArguments] componentsJoinedByString:@" "],
                   @kRsyncArgs, nil];
        ipcErr = BASExecuteRequestInHelperTool(gAuth,
                                               kYargCommandSet,
                                               (CFStringRef) [[NSBundle mainBundle] bundleIdentifier],
                                               (CFDictionaryRef) request,
                                               (CFDictionaryRef *) &response);
        if (ipcErr == noErr) {
            commandErr = BASGetErrorFromResponse((CFDictionaryRef)response);
            if (commandErr != noErr) {
                NSLog(@"Helper tool succeeded but returned error %d", commandErr);
                return;
            }
        } else {
            failCode = BASDiagnoseFailure(gAuth, (CFStringRef) [[NSBundle mainBundle] bundleIdentifier]);
            switch (failCode) {
                case kBASFailDisabled:
                    smartLog(@"[... tell the user that tool is installed but disabled ...]");
          //          [... offer to enable it...]
                    break;
                case kBASFailPartiallyInstalled:
                    smartLog(@"[... tell the user that tool is installed incorrectly ...]");
         //           [... offer to correct it...]
                    break;
                case kBASFailNotInstalled:
                    smartLog(@"[... tell the user that tool is not installed ...]");
      //              [... offer to install it...]
                    break;
                default:
                    smartLog(@"[... tell the user something generic ...]");
     //               [... offer to reinstall it ...]
                    break;
            }
            // if [... user agrees ...]
            if ( true ) {
                installErr = BASFixFailure(
                                           gAuth, 
                                           (CFStringRef) [[NSBundle mainBundle] bundleIdentifier], 
                                           CFSTR("InstallTool"), 
                                           CFSTR("HelperTool"), 
                                           failCode
                                           );
                
                if (installErr == noErr) {
                    smartLog(@"retry request here");
                    return;
                } else {
                    smartLog(@"Unable to run helper tool");
                    return;
                }
            }
        }
        
        //*** If we got this far, helper tool must've succeeded
        rsyncOutDescriptor = [[[response
                                objectForKey:@kBASDescriptorArrayKey]
                               objectAtIndex:0] intValue];
        rsyncOutput = [[[NSFileHandle alloc] initWithFileDescriptor:rsyncOutDescriptor] autorelease];
        rsyncPID = (pid_t) [[response objectForKey:@kRsyncPID] intValue];
    } else {
        NSPipe * outpipe = [NSPipe pipe];
        [rsyncTask setStandardOutput:outpipe];
        rsyncOutput = [outpipe fileHandleForReading];
        // Keeping this tentatively if I can use it to kill rsync when force quit
        /*
         NSPipe * inpipe = [NSPipe pipe];
         [rsyncTask setStandardInput:inpipe];
         NSFileHandle *rsyncInput = [inpipe fileHandleForWriting]; 
         */
        [rsyncTask launch];
    }
	id runButton = [arguments objectAtIndex:0];
	NSData * nextChunk;
	NSString * currentOutput;
    isBuildingFileList = YES;
    smartLog(@"about to start rsync loop");
	// Is it better (and possible) to do this loop asynchronously with NSFileHandle#readInBackgroundAndNotify ?
	// Additionally, should this loop have its own pool for each loop to conserve memory, or is that overkill?
	while ([(nextChunk = [rsyncOutput availableData]) length] != 0) {
		currentOutput = [[[NSString alloc] initWithData:nextChunk encoding:NSUTF8StringEncoding] autorelease];
//		smartLog(@"rsync: %@", currentOutput);
        NSCharacterSet * newLineSet = [NSCharacterSet characterSetWithCharactersInString:@"\r\n\v\f"];
        NSArray *lines = [currentOutput componentsSeparatedByCharacterSet:newLineSet];
        NSEnumerator * lineEnum = [lines objectEnumerator];
        NSString * line;
        while ((line = [lineEnum nextObject])) {
            [self setProgressForOutput:line];
        }
	}
    smartLog(@"Finished with rsync loop");
    [rsyncOutput closeFile];
    if ([[self activeJob] runAsRoot]) {
        close(rsyncOutDescriptor);
    } else {
        [rsyncTask waitUntilExit];
    }
	[backupRunningPanel orderOut:self];
	// Finder can't seem to tell that files have changed unless you tell it:
	[[NSWorkspace sharedWorkspace] noteFileSystemChanged:[[self activeJob] pathTo]];
	[NSApp endSheet:backupRunningPanel returnCode:1];
	commandErr = [rsyncTask terminationStatus];
	// TODO: Need user-visible error handling!
	if (commandErr == 0)
		smartLog(@"Rsync did okay");
	else if (commandErr == 20) // rsync recieved SIGUSR1 or SIGINT
		smartLog(@"rsync was cancelled by the user");
	else
		smartLog(@"rsync crapped out; exit status %d", commandErr);
	[rsyncTask release];
	rsyncTask = nil;
	[spinner stopAnimation:self];
    [fileProgress setIndeterminate:YES];
    [fileProgress stopAnimation:self];
	[arguments release];
	[pool release];
	// TODO: This doesn't seem to be thread-safe.  Send a notification to the main thread instead.
	[runButton setEnabled:YES];
}

- (IBAction)stopCurrentBackupJob:(id)sender
{
    if ([[self activeJob] runAsRoot]) {
        OSStatus ipcErr;
        NSDictionary *  request;
        NSDictionary * response;
        
        response = NULL;
        request = [NSDictionary 
                   dictionaryWithObjectsAndKeys:
                   @kStopRsyncCommand, 
                   @kBASCommandKey,
                   [NSNumber numberWithInt:(int) rsyncPID],
                   @kRsyncPID, nil];
        ipcErr = BASExecuteRequestInHelperTool(gAuth,
                                               kYargCommandSet,
                                               (CFStringRef) [[NSBundle mainBundle] bundleIdentifier],
                                               (CFDictionaryRef) request,
                                               (CFDictionaryRef *) &response);
    } else {
        [rsyncTask terminate];
    }

	
}

- (IBAction)cancelPassword:(id)sender {
	[NSApp abortModal];
}

- (IBAction)okayPassword:(id)sender {
	[NSApp stopModal];
}

- (IBAction)killJob:(id)sender
{		
	if (! modifying) { // new job
		[self deleteJob:sender];
	}
	modifying = NO;
	[self dismissJobEditSheet];
}

- (IBAction)browseFrom:(id)sender{
	NSOpenPanel *op = [NSOpenPanel openPanel];
	[op setTitle: @"Directory to copy from"];
	[mainView makeFirstResponder: pathFrom];
	[self locateDirWithOpenPanel:op forField: pathFrom];
}

- (IBAction)browseTo:(id)sender {
	NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanCreateDirectories:YES];
	[op setTitle: @"Directory to copy to"];
	[mainView makeFirstResponder: pathTo];
	[self locateDirWithOpenPanel:op forField: pathTo];	
}

- (IBAction)switchAdvancedBasicView:(id)sender {
	int bOrS = [basicOrAdvanced selectedSegment];
	// Are we clicking basic when already in basic?
	if (basicMode && bOrS == 0)
		return;
	// Are we clicking advanced when already in advanced?
	else if ((!basicMode) && bOrS == 1)
		return;
	// switch to basic:
	else if (bOrS == 0) {
		basicMode = YES;
		[self resizeForAdvancedOrBasic:-200 animate: YES];
	}
	else {
		// switch to advanced:
		basicMode = NO;
		[self resizeForAdvancedOrBasic:200 animate: YES];
	}
}

- (IBAction)dayOfWeekPressed:(id)sender {
	
}

- (IBAction)toggleDrawer:(id)sender {
	[advancedDrawer toggle:sender];
}


- (IBAction)resizeBackupWindow:(id)sender {
	
	if ([sender state] == NSOffState){
/*        [optBox setEnabled:NO];
		//	[self shrinkBackupWindow];
		for (unsigned x = 0; x < [subviews count]; x++) {
			[[subviews objectAtIndex:x] setEnabled:NO];
		}
		[[self activeJob] setScheduled:NO];
 */
        [self setTabView:optBox Enabled:NO];
	}
	else {
		/*	[self growBackupWindow];
        [optBox setEnabled:YES];
		for (unsigned x = 0; x < [subviews count]; x++) {
			[[subviews objectAtIndex:x] setEnabled:YES];
		}
		[[self activeJob] setScheduled:YES]; */
        [self setTabView:optBox Enabled:YES];
	}
}

- (void)setTabView:(NSTabView *)tabView Enabled:(BOOL)enable {
    NSEnumerator * tabs = [[tabView tabViewItems] objectEnumerator];
    id nextView;
    NSTabViewItem *tabViewItem;
    // Enumerate through all the items in the TabView and disable them if possible.
    while ((tabViewItem = [tabs nextObject])) {
        NSEnumerator * views = [[[tabViewItem view] subviews] objectEnumerator];
        while ((nextView = [views nextObject])) {
            [nextView setEnabled: enable ? YES : NO];
        }
    }
}

/*******     Functions called from within Yargcontroller or other code directly     *******
********/

#pragma mark Internal Functions

- (id)init {
	self = [super init];
	modifying = NO;
	defaultTime = [[NSDateComponents alloc] init];
	[defaultTime setHour: 16];
	[defaultTime setMinute:0];
	sharedDefaults = [[NSUserDefaults standardUserDefaults] retain];
	[sharedDefaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		@"/usr/bin/rsync", @"rsyncPath", @"", @"defaultExcludeList", nil]];
	return self;
}

- (void)awakeFromNib {
	// sharedDefaults:Jobs is a dictionary containing NameOfJob:DictOfJob pairs
	// as spit out from Job#asSerializedDictionary and potentially stored
	// in an NSUserDefaults plist.
	if ([sharedDefaults dictionaryForKey:@"Jobs"] == nil) {
		jobsDictionary = [[NSMutableDictionary dictionary] retain];
	} else {
		jobsDictionary = [[NSMutableDictionary dictionaryWithDictionary:[sharedDefaults dictionaryForKey:@"Jobs"]] retain];
	}
	NSAssert([jobsDictionary isKindOfClass:[NSMutableDictionary class]] == YES, @"jobsDictionary is not an NSMutableDictionary");
	[sharedDefaults setObject:jobsDictionary forKey:@"Jobs"];
	NSEnumerator *jobEnum = [jobsDictionary objectEnumerator];
	NSDictionary *job;
	while ((job = [jobEnum nextObject])) {
		[jobList addObject:[Job jobFromDict:job]];
	}
	
	/* Set cells in TableView to truncate at beginning instead of default end */
	NSTextFieldCell *from = [[windowList tableColumnWithIdentifier:@"FromColumn"] dataCell];
	NSTextFieldCell *to = [[windowList tableColumnWithIdentifier:@"ToColumn"] dataCell];
	[from setLineBreakMode:NSLineBreakByTruncatingHead];
	[to setLineBreakMode:NSLineBreakByTruncatingHead];
    
    NSString *suffix = nil;
	/* Initialize the day-of-month picker */
    for (int i = 4; i < 32; i++) {
        suffix = suffixForNum(i);
        [dayOfMonthPopup addItemWithTitle:[NSString stringWithFormat:@"%d%@", i, suffix]];
    }
    
	NSRect frame = [createJobPanel frame];
	frame.origin.x -= 100;
	frame.size.width -= 200;
	[createJobPanel setFrame:frame display:YES];
	
	NSArray * subviews = [[[optBox subviews] objectAtIndex:0] subviews];
	for (unsigned x = 0; x < [subviews count]; x++) {
		[[subviews objectAtIndex:x] setEnabled:NO];
	}
	basicMode = YES;
	NSNotificationCenter * defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self 
					  selector:@selector(applicationWillTerminate:)
						  name:@"NSApplicationWillTerminateNotification" 
						object:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(newJob:) && 
        ([backupRunningPanel isVisible] || [createJobPanel isVisible])) {
        return NO;
    }
    if ([menuItem action] == @selector(stopCurrentBackupJob:) && ![backupRunningPanel isVisible]) {
        return NO;
    }
    return YES;
}

-(void)editSelectedJob {
	Job * job = [self activeJob];
	[jobName setStringValue: [job jobName]];
	[pathFrom setStringValue: [job pathFrom]];
	[pathTo setStringValue: [job pathTo]];
    [dayOfWeekChooser deselectAllCells];
    [scheduleCheckbox setState: [job scheduleStyle] == ScheduleNone ? NSOffState : NSOnState];
    [self resizeBackupWindow:scheduleCheckbox];
    if ([job scheduleStyle] == ScheduleWeekly) {
        [optBox selectTabViewItemAtIndex:1];
        NSEnumerator * enumer = [[job daysToRun] objectEnumerator];
        NSNumber *nextDay;
        while ((nextDay = [enumer nextObject])) {
            [dayOfWeekChooser selectCellWithTag:[nextDay intValue]];
        }
        [timeWeekInput setDateValue:[[NSCalendar currentCalendar] dateFromComponents:[job timeOfJob]]];
    } else if ([job scheduleStyle] == ScheduleMonthly) {
        [optBox selectTabViewItemAtIndex:0];
        [dayOfMonthPopup selectItemAtIndex:[[[job daysToRun] objectAtIndex:0] intValue]-1];
        [timeMonthInput setDateValue:[[NSCalendar currentCalendar] dateFromComponents:[job timeOfJob]]];
    }
	[deleteRemote setState: [job deleteChanged] ? NSOnState : NSOffState ];
	[copyHidden setState: [job copyHidden] ? NSOnState : NSOffState ];
	[copyExtended setState: [job copyExtended] ? NSOnState : NSOffState ];
    [runAsRootCheckbox setState: [job runAsRoot] ? NSOnState : NSOffState ];
	[filesToIgnore setString: [[job excludeList] componentsJoinedByString:@" "]];
	// if job doesn't match defaults, show Advanced
	if (! ([job deleteChanged] && (![job copyHidden]) && (![job copyExtended]))) {
		[basicOrAdvanced setSelectedSegment:1];
		[self switchAdvancedBasicView:basicOrAdvanced];
	}
	[NSApp beginSheet: createJobPanel
	   modalForWindow: mainView
		modalDelegate: self
	   didEndSelector: NULL
		  contextInfo: NULL];
	[createJobPanel orderFront:self];
}

- (void)dismissJobEditSheet {
	[windowList reloadData];
	[createJobPanel orderOut:self];
	[NSApp endSheet:createJobPanel returnCode:1];
	// returning window to default state should really go here:
	[dayOfWeekChooser selectCellAtRow:0 column:0];
	[timeWeekInput setDateValue:[[NSCalendar currentCalendar] dateFromComponents:defaultTime]];
	if ([basicOrAdvanced selectedSegment] == 1) {
		[basicOrAdvanced setSelectedSegment:0];
		[self switchAdvancedBasicView:basicOrAdvanced];
	}
	[createJobPanel makeFirstResponder:jobName];
}

/** When we modify a launchd job we have to tell launchd to unload it then reload it.
    if it's never been unloaded and unload results in an error, I don't care. 
 **/
- (void)informLaunchd:(Job *) job {
	NSTask *unload = [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" 
											  arguments:[NSArray arrayWithObjects: @"unload", [job pathToPlist], nil]];
	if ([unload isRunning])
		[unload waitUntilExit];
	smartLog(@"launchd job for %@ unloaded", [job jobName]);
	NSTask *load = [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl"
											arguments:[NSArray arrayWithObjects: @"load", [job pathToPlist], nil]];
	smartLog(@"loading job %@ at %@ in launchd:", [job jobName], [job pathToPlist]);
	[load waitUntilExit];
	smartLog(@"done waiting for launchd.");
	smartLog(@"launchd temination status: %d", [load terminationStatus]);
}

// TODO: This should check rsync version somehow and not run if it's not the right version.
- (void)setProgressForOutput:(NSString *)line {
    if ([line length] == 0) {
        return;
    }
    // Only display filename, not full path.  Is this wanted?
    smartLog(@"rsync line: %@", line);
    if ([line characterAtIndex:0] == ' ' && isBuildingFileList) {
        NSArray * bits = [line componentsSeparatedByString:@" "];
        NSString * message = [NSString stringWithFormat:@"Checking existing files: %@ files checked", 
                              [bits objectAtIndex:1]];
        [filenamePrompt setStringValue:message];
    } else if ([line characterAtIndex:0] == ' ') {
        NSScanner * scanner = [NSScanner scannerWithString:line];
        [scanner setCharactersToBeSkipped:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
        int number;
        int filePercent;
        float percent;
        // amount transferred
        [scanner scanInt:&number];
        // percentage of file transferred
        [scanner scanInt:&filePercent];
        if ([line rangeOfString:@"("].location == NSNotFound) {
            [fileProgress setDoubleValue:filePercent];
        } else {
            // speed of transfer
            [scanner scanFloat:&percent];
            // three parts of a time
            [scanner scanInt:&number];[scanner scanInt:&number];[scanner scanInt:&number];
            // Number's index
            [scanner scanInt:&number];
            // Total percentage transferred
            [scanner scanFloat:&percent];
            [spinner setDoubleValue:percent];
            [fileProgress setDoubleValue:100.0];
        }
    } else if (isBuildingFileList) {
        if ([line rangeOfString:@"files to consider"].location != NSNotFound) {
            isBuildingFileList = NO;
//            [filenamePrompt setStringValue:@"Done checking local files."];
            [filenamePrompt setStringValue:@"Current file:"];
            [spinner setIndeterminate:NO];
            [fileProgress setIndeterminate:NO];
            //                    [fileProgress startAnimation:self];
        } else {
            [filenamePrompt setStringValue:@"Checking existing files:"];
        }
    } else {
        [copyingFileName setStringValue:[[line pathComponents] lastObject]];
    }
}

- (void) resizeForAdvancedOrBasic:(int)amountToChange animate:(BOOL)bl {
	NSRect frame = [createJobPanel frame];
	frame.origin.x -= amountToChange / 2;
	frame.size.width += amountToChange;
	[createJobPanel setFrame:frame display:YES animate: bl];
}

- (void) locateDirWithOpenPanel:(NSOpenPanel *)op forField:(NSTextField *)field
{
	[op setPrompt: @"Choose"];
	[op setCanChooseFiles:NO];
	[op setCanChooseDirectories:YES];
	[op setAllowsMultipleSelection:NO];
	int result = [op runModalForDirectory:[field stringValue] file:nil types:nil];
	if (result != NSOKButton)
		return;
	[field setStringValue: [[op filenames] objectAtIndex: 0]];
	
}

-(void)freakoutAlertTitle:(NSString *)alertTitle Text:(NSString *)alertText {
	NSBeginCriticalAlertSheet(alertTitle, @"Okay", 
							  nil, 
							  nil, 
							  createJobPanel, 
							  self, 
							  NULL, 
							  NULL, 
							  NULL,							 
							  alertText);
}

- (Job *)activeJob {
	return [[jobList selectedObjects] objectAtIndex: 0];
}

- (void)dealloc 
{
	[jobsDictionary release];
	[sharedDefaults release];
	[super dealloc];
}

- (void)applicationWillTerminate:(id)sender {
	[self synchronizeSettingsToDisk:sender];
	if (rsyncTask && [rsyncTask isRunning]) {
		[rsyncTask terminate];
	}
}

- (void)synchronizeSettingsToDisk:(id)notification {
	[sharedDefaults setObject:jobsDictionary forKey:@"Jobs"];
	[sharedDefaults synchronize];
}



/**** Old code kept around in case I want to use it again:
 ****

#define BACKUPWINDOWADJUSTMENT 130

 - (void)shrinkBackupWindow {
	 NSString * effect;
	 NSRect frame = [createJobPanel frame];
	 frame.size.height -= BACKUPWINDOWADJUSTMENT;
	 frame.origin.y += BACKUPWINDOWADJUSTMENT;
	 effect = NSViewAnimationFadeOutEffect;
	 NSViewAnimation * animation = [[NSViewAnimation alloc] initWithViewAnimations:
		 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:
			 optBox, NSViewAnimationTargetKey, effect, NSViewAnimationEffectKey, nil],
			 [NSDictionary dictionaryWithObjectsAndKeys:
				 createJobPanel, NSViewAnimationTargetKey, [NSValue valueWithRect:frame], NSViewAnimationEndFrameKey, nil], nil]];
	 [animation startAnimation];
	 [animation release];
 }
 
 - (void)growBackupWindow {
	 NSString * effect;
	 NSRect frame = [createJobPanel frame];
	 frame.size.height += BACKUPWINDOWADJUSTMENT;
	 frame.origin.y -= BACKUPWINDOWADJUSTMENT;
	 effect = NSViewAnimationFadeInEffect;
	 NSViewAnimation * animation = [[NSViewAnimation alloc] initWithViewAnimations:
		 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:
			 optBox, NSViewAnimationTargetKey, effect, NSViewAnimationEffectKey, nil],
			 [NSDictionary dictionaryWithObjectsAndKeys:
				 createJobPanel, NSViewAnimationTargetKey, [NSValue valueWithRect:frame], NSViewAnimationEndFrameKey, nil], nil]];
	 [animation startAnimation];
	 [animation release];
 }


****/


@end
