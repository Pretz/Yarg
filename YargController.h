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
#import <Security/Security.h>

@interface YargController : NSObject
{
    /**** EXTERNAL OBJECTS ****/
    IBOutlet NSArrayController *jobList;
    
    /**** WINDOWS ****/
    IBOutlet NSWindow *createJobPanel;
	IBOutlet NSWindow *mainView;
    IBOutlet NSWindow *passwordPanel;
    IBOutlet NSWindow *backupRunningPanel;
    
    /**** MAIN WINDOW ****/
    IBOutlet NSTableView *windowList;
    
    /**** NEW JOB WINDOW ****/
    IBOutlet NSTextField *jobName;
	IBOutlet NSTextField *pathFrom;
	IBOutlet NSTextField *pathTo;
    IBOutlet NSSegmentedControl *basicOrAdvanced;
    /** date picker **/
	IBOutlet NSTabView *optBox;
    IBOutlet NSButton *scheduleCheckbox;
	IBOutlet NSMatrix *dayOfWeekChooser;
	IBOutlet NSDatePicker *timeWeekInput;
    IBOutlet NSDatePicker *timeMonthInput;
    IBOutlet NSPopUpButton *dayOfMonthPopup;
    /** advanced controls **/
    IBOutlet NSButton *deleteRemote;
	IBOutlet NSButton *copyHidden;
	IBOutlet NSButton *copyExtended;
	IBOutlet NSTextView *filesToIgnore;
    IBOutlet NSButton *runAsRootCheckbox;
    
    /**** RSYNC PROGRESS PANEL ****/
    IBOutlet NSTextField *runningBackupName;
	IBOutlet NSTextField *copyingFileName;
    IBOutlet NSTextField *filenamePrompt;
	IBOutlet NSProgressIndicator *spinner;
    IBOutlet NSProgressIndicator *fileProgress;
    
    /**** PASSWORD WINDOW ****/
	IBOutlet NSTextField *passwordRequestText;
	IBOutlet NSTextField *passwordEntryField;
    
    /**** UNCONNECTED ??? ****/
	IBOutlet NSPopUpButton *backupChooser;
	IBOutlet NSDrawer *advancedDrawer;
	
	@private
	NSUserDefaults *sharedDefaults;
	bool modifying;
	bool basicMode;
	NSMutableDictionary *jobsDictionary;
	NSDateComponents *defaultTime;
	NSTask *rsyncTask;
    pid_t rsyncPID;
	pid_t processGroup;
    BOOL isBuildingFileList;
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
- (IBAction)stopCurrentBackupJob:(id)sender;

- (void)locateDirWithOpenPanel:(NSOpenPanel *)op forField:(NSTextField *)field;
- (void)dismissJobEditSheet;
- (void)editSelectedJob;
- (void)freakoutAlertTitle:(NSString *)alertTitle Text: (NSString *)alertText;
- (void)synchronizeSettingsToDisk:(id)notification;
- (void)applicationWillTerminate:(id)sender;
@end
