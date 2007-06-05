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

/* YargController */

#import <Cocoa/Cocoa.h>

#import "Job.h"
#import "additions.h"

@interface YargController : NSObject
{
    IBOutlet NSArrayController *jobList;
	IBOutlet NSTableView *windowList;
	IBOutlet NSWindow *createJobPanel;
	IBOutlet NSWindow *mainView;
	IBOutlet NSTextField *jobName;
	IBOutlet NSTextField *pathFrom;
	IBOutlet NSTextField *pathTo;
	IBOutlet NSView *optBox;
	IBOutlet NSTextField *runningBackupName;
	IBOutlet NSTextField *copyingFileName;
	IBOutlet NSWindow *backupRunningPanel;
	IBOutlet NSProgressIndicator *spinner;
	IBOutlet NSButton *scheduleCheckbox;
	IBOutlet NSMatrix *dayOfWeekChooser;
	IBOutlet NSDatePicker *timeInput;
	IBOutlet NSPopUpButton *backupChooser;
	IBOutlet NSButton *deleteRemote;
	IBOutlet NSButton *copyHidden;
	IBOutlet NSButton *copyExtended;
	IBOutlet NSSegmentedControl *basicOrAdvanced;
	IBOutlet NSTextView *filesToIgnore;
	IBOutlet NSDrawer *advancedDrawer;
	IBOutlet NSWindow *passwordPanel;
	IBOutlet NSTextField *passwordRequestText;
	IBOutlet NSTextField *passwordEntryField;
	
	@private
	NSUserDefaults *sharedDefaults;
	bool modifying;
	bool basicMode;
	NSMutableDictionary *jobsDictionary;
	NSDateComponents *defaultTime;
}
- (IBAction)deleteJob:(id)sender;
- (IBAction)modifyJob:(id)sender;
- (IBAction)newJob:(id)sender;
- (IBAction)runJob:(id)sender;
- (IBAction)saveJob:(id)sender;
- (IBAction)killJob:(id)sender;
- (IBAction)browseFrom:(id)sender;
- (IBAction)browseTo:(id)sender;
- (IBAction)resizeBackupWindow:(id)sender;
- (IBAction)dayOfWeekPressed:(id)sender;
- (IBAction)switchAdvancedBasicView:(id)sender;
- (IBAction)toggleDrawer:(id)sender;
- (IBAction)cancelPassword:(id)sender;
- (IBAction)okayPassword:(id)sender;

- (void)locateDirWithOpenPanel:(NSOpenPanel *)op forField:(NSTextField *)field;
- (void)dismissJobEditSheet;
- (void)editSelectedJob;
- (void)freakoutAlertTitle:(NSString *)alertTitle Text: (NSString *)alertText;
- (void)applicationTerminating:(id)notification;
@end
