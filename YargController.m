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

#import "YargController.h"
#import "Job.h"
#import "additions.h"

// A few internal functions I only want to use within YargController
@interface YargController (private)
- (void) shrinkBackupWindow;
- (void) growBackupWindow;
- (Job *) activeJob;
- (void) resizeForAdvancedOrBasic:(int)amountToChange animate:(BOOL)bl; 
- (void) informLaunchd:(Job *) job;
@end


@implementation YargController 

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
	// Make sure no other jobs have the same name (not including whitespace)
	NSString * errorFormat = @"You already have a job named \"%@\", not counting case or punctuation. "
	@"Please give your job a different name.";
	NSEnumerator *jobEnum = [[jobList content] objectEnumerator];
	Job *currentJob;
	while((currentJob = [jobEnum nextObject])) {
		if ([[[jobName stringValue] stringWithoutSpaces] 
				caseInsensitiveCompare:[[currentJob jobName] stringWithoutSpaces]] == NSOrderedSame &&
			currentJob != [self activeJob]) {
			[self freakoutAlertTitle:@"Name Collision" Text: 
				[NSString stringWithFormat: errorFormat, [currentJob jobName]]];
			return;
		}
	}
	/* If we're modifying jobName, gotta make sure to remove old job (which is keyed off of jobName)
		from defaults. */
	if (modifying && (![strippedJobName isEqualToString:[[job jobName] stringWithoutSpaces]])) {
		[jobsDictionary removeObjectForKey:[job jobName]];
	}
	smartLog(@"new job called %@", strippedJobName);
	[job setJobName: strippedJobName];
	[job setPathFrom: strippedPathFrom];
	[job setPathTo: strippedPathTo];
	[job setExcludeList:[[filesToIgnore string] componentsSeparatedByString:@" "]];
	if ([job scheduled]) {
		[job setDayOfWeek:[dayOfWeekChooser selectedColumn]];
		NSCalendarDate *date = [[timeInput dateValue] dateWithCalendarFormat:nil timeZone:nil];
		[job setTimeOfJob:[[NSCalendar currentCalendar] components:NSHourCalendarUnit | NSMinuteCalendarUnit
														  fromDate:date]];
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
	[self dismissJobEditSheet];
}

- (IBAction)runJob:(id)sender
{
	[sender setEnabled:NO];
	Job * job = [self activeJob];
	NSTask *rsync = [[NSTask alloc] init];
	[rsync setLaunchPath:[job rsyncPath]];
	// TODO: exclude patterns
	[rsync setArguments:[[job rsyncArguments] arrayByAddingObject:@"--no-detach"]];
	smartLog(@"rsync args: %@", [job rsyncArguments]);
	[NSApp beginSheet: backupRunningPanel
	   modalForWindow: mainView
		modalDelegate: self
	   didEndSelector: NULL
		  contextInfo: NULL];
	[spinner startAnimation:self];
	NSPipe * outpipe = [NSPipe pipe];
	[rsync setStandardOutput:outpipe];
	NSFileHandle * rsyncOutput = [outpipe fileHandleForReading];
	/*	NSPipe * inpipe = [NSPipe pipe];
	[rsync setStandardInput:inpipe];
	NSFileHandle *rsyncInput = [inpipe fileHandleForWriting]; 
	*/
	NSData * nextChunk;
	NSString * currentOutput;
	[rsync launch];
	smartLog(@"rsync launched");
	while ([nextChunk = [rsyncOutput availableData] length] != 0) {
		currentOutput = [[NSString alloc] initWithData:nextChunk encoding: NSUTF8StringEncoding];
		smartLog(@"ll: %@", currentOutput);
		
		/* // SECTION REMOVED: It doesn't seem like I can actually pass a password to rsync :(
		   // I will have to require keys.
			
			if ([currentOutput rangeOfString:@"Enter passphrase for key"].location != NSNotFound) {
				[passwordRequestText setStringValue: currentOutput];
				if ([NSApp runModalForWindow:passwordPanel] == NSRunStoppedResponse) {
					NSString * password = [passwordEntryField stringValue];
					smartLog(@"Password: %@", password);
				} else {
					// Cancel pressed, kill job...
					[rsync terminate];
				}
			} else if ([currentOutput rangeOfString:@"Are you sure you want to continue connecting"].location != NSNotFound) {
				// TODO: Does this need to be a dialog?  If we're talking security, then yes.
				[rsyncInput writeData:[NSData dataWithBytes:"yes" length:4]];
			}
		*/
		[copyingFileName setStringValue:currentOutput];
		// since we're hogging the run loop, need to tell progress window to update itself:
		[backupRunningPanel display];
		[currentOutput release];
	}
	[rsync waitUntilExit];
	[backupRunningPanel orderOut:self];
	// Finder can't seem to tell that files have changed unless you tell it:
	[[NSWorkspace sharedWorkspace] noteFileSystemChanged:[job pathTo]];
	[NSApp endSheet:backupRunningPanel returnCode:1];
	int stat = [rsync terminationStatus];
	if (stat == 0)
		smartLog(@"Rsync did okay");
	else
		smartLog(@"rsync crapped out");
	[rsync release];
	[spinner stopAnimation:self];
	[sender setEnabled:YES];
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
	NSArray * subviews = [[[optBox subviews] objectAtIndex:0] subviews];
	if ([sender state] == NSOffState){
		//	[self shrinkBackupWindow];
		for (unsigned x = 0; x < [subviews count]; x++) {
			[[subviews objectAtIndex:x] setEnabled:NO];
		}
		[[self activeJob] setScheduled:NO];
	}
	else {
		//	[self growBackupWindow];
		for (unsigned x = 0; x < [subviews count]; x++) {
			[[subviews objectAtIndex:x] setEnabled:YES];
		}
		[[self activeJob] setScheduled:YES];
	}
}

/*******     Functions called from within Yargcontroller or other code directly     *******
********/

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
					  selector:@selector(applicationTerminating:)
						  name:@"NSApplicationWillTerminateNotification" 
						object:nil];
		
}

-(void)editSelectedJob {
	Job * job = [self activeJob];
	[jobName setStringValue: [job jobName]];
	[pathFrom setStringValue: [job pathFrom]];
	[pathTo setStringValue: [job pathTo]];
	if ([scheduleCheckbox state] == NSOffState && [job scheduled]) {
		[scheduleCheckbox setState:NSOnState];
		[self resizeBackupWindow:scheduleCheckbox];
	} else if ([scheduleCheckbox state] == NSOnState && ![job scheduled]) {
		[scheduleCheckbox setState:NSOffState];
		[self resizeBackupWindow:scheduleCheckbox];
	}
	if ([job scheduled]) {
		[dayOfWeekChooser selectCellAtRow:0 column:[job dayOfWeek]];
		[timeInput setDateValue:[[NSCalendar currentCalendar] dateFromComponents:[job timeOfJob]]];
	}
	[deleteRemote setState: [job deleteChanged] ? NSOnState : NSOffState ];
	[copyHidden setState: [job copyHidden] ? NSOnState : NSOffState ];
	[copyExtended setState: [job copyExtended] ? NSOnState : NSOffState ];
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
	[timeInput setDateValue:[[NSCalendar currentCalendar] dateFromComponents:defaultTime]];
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
	smartLog(@"loading job %@ in launchd:", [job jobName]);
	[load waitUntilExit];
	smartLog(@"done waiting for launchd.");
	smartLog(@"launchd temination status: %d", [load terminationStatus]);
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
	int result = [op runModalForTypes:nil];
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

- (void)applicationTerminating:(id)notification {
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
