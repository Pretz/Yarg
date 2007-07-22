//
//  Job.m
//  yarg
//
//  Created by Alex Pretzlav on 11/9/06.
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
#import "Job.h"


@implementation Job
/*
+ (Job)newJobFromPanel:(NSPanel *)panel modalFor:(NSWindow *)window {
	[NSApp beginSheet: panel
	   modalForWindow: window
		modalDelegate: self
	   didEndSelector: NULL
		  contextInfo: NULL];
}
*/

/*! @param pathToPlist An absolute path to the plist file this job should be initialized from.
 */
+ (Job *)jobFromPlist:(NSString *)pathToPlist {
	Job * job = [Job jobFromDict:[NSDictionary dictionaryWithContentsOfFile:pathToPlist]];
	job->pathToPlist = [pathToPlist copy];
	return job;
}

/*! Returns a new job initialized from dictionary.  dictionary is a dictionary
    as returned from asSerializedDictionary
*/
+ (Job *)jobFromDict:(NSDictionary *)dictionary {
	smartLog(@"jobFromDict:\n%@", dictionary);
	Job * job = [[Job alloc] initWithPathFrom:[dictionary objectForKey:@"pathFrom"]
									   pathTo:[dictionary objectForKey:@"pathTo"]
									  jobName:[dictionary objectForKey:@"jobName"]];
	[job setRsyncPath: [dictionary objectForKey:@"Program"]];
	NSDictionary *dateInfo;
	if ((dateInfo = [dictionary objectForKey:@"StartCalendarInterval"]) != nil) {
		[job setScheduled:YES];
		job->hourOfDay = [[dateInfo objectForKey:@"Hour"] intValue];
		job->minuteOfHour = [[dateInfo objectForKey:@"Minute"] intValue];
		[job setDayOfWeek:[[dateInfo objectForKey:@"Weekday"] intValue]];
	}
	[job setCopyHidden: [[dictionary objectForKey:@"copyHidden"] boolValue]];
	[job setDeleteChanged: [[dictionary objectForKey:@"deleteChanged"] boolValue]];
	[job setCopyExtended: [[dictionary objectForKey:@"copyExtended"] boolValue]];
	[job setExcludeList: [dictionary objectForKey:@"excludeList"]];
	[job setPathToPlist: [dictionary objectForKey:@"pathToPlist"]];
	return [job autorelease];
}

/*! Designated initializer
*/
- (id)init {
	if ((self = [super init]) != nil) {
		pathFrom = nil;
		pathTo = nil;
		jobName = nil;
		rsyncPath = [[[NSUserDefaults standardUserDefaults] objectForKey:@"rsyncPath"] copy];
		// sane defaults:
		copyExtended = NO;
		runAsRoot = NO;
		copyHidden = NO;
		deleteChanged = YES;
		scheduled = NO;
		pathToPlist = nil;
		excludeList = [[NSMutableArray arrayWithCapacity:1] retain];
	}
	return self;
}

- (id)initWithPathFrom:(NSString *)path1 pathTo:(NSString *)path2 jobName:(NSString *)name {
	if ((self = [self init]) != nil) {
		[self setPathFrom: path1];
		[self setPathTo: path2];
		[self setJobName: name];
	}
	return self;
}

- (NSDictionary *)asLaunchdPlistDictionary {
	NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[dict setObject:[[NSString stringWithFormat:@"%@%@", @"com.yarg.", jobName] stringWithoutSpaces] 
			 forKey:@"Label"];
	NSMutableArray *programArguments = [NSMutableArray arrayWithObject:[self rsyncPath]];
	[programArguments addObjectsFromArray:[self rsyncArguments]];
	if (scheduled) {
		[dict setObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:hourOfDay], @"Hour",
			[NSNumber numberWithInt:minuteOfHour], @"Minute",
			[NSNumber numberWithInt: dayOfWeek], @"Weekday", nil] 
				 forKey:@"StartCalendarInterval"];
	} else {
		[dict setObject:[NSNumber numberWithBool:YES] forKey:@"Disabled"];
	}
	[dict setObject:programArguments forKey:@"ProgramArguments"];
	[dict setObject:[self rsyncPath] forKey:@"Program"];
	[dict setObject:jobName forKey:@"ServiceDescription"];
	// dictionaryWithCapacity returns a pre-autoreleased object that I can just return, right?
	return dict;
}

/*!  Returns a Dictionary object with contains everything important there is to know about
     this job, and can be re-created into an identical job with jobFromDict:
 */
- (NSDictionary *)asSerializedDictionary {
	NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithCapacity: 4];
	[dict setObject:[NSString stringWithFormat:@"com.yarg.%@", [jobName stringWithoutSpaces]]
			 forKey:@"Label"];
	[dict setObject:[NSNumber numberWithBool:copyExtended] forKey:@"copyExtended"];
	[dict setObject:[NSNumber numberWithBool:copyHidden] forKey:@"copyHidden"];
	[dict setObject:[NSNumber numberWithBool:deleteChanged] forKey:@"deleteChanged"];
	[dict setObject:excludeList forKey:@"excludeList"];
	[dict setObject:pathFrom forKey:@"pathFrom"];
	[dict setObject:pathTo forKey:@"pathTo"];
	[dict setObject:pathToPlist forKey:@"pathToPlist"];
	[dict setObject:jobName forKey:@"jobName"];
	if (scheduled) {
		[dict setObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:hourOfDay], @"Hour",
			[NSNumber numberWithInt:minuteOfHour], @"Minute",
			[NSNumber numberWithInt: dayOfWeek], @"Weekday", nil] 
				 forKey:@"StartCalendarInterval"];
	}
	[dict setObject:[self rsyncPath] forKey:@"Program"];
	// dictionaryWithCapacity returns a pre-autoreleased object that I can just return, right?
	return dict;
}
/*! Writes a launchd plist file according to launchd.plist(5) into the appropriate LaunchAgents dir
 *  for the current user. Returns YES on success and NO on failure.
 */
- (BOOL)writeLaunchdPlist {
	if (runAsRoot) {
		smartLog(@"Root backup jobs incomplete");
	} else {
		// This is supposed to be "portable":
		NSArray *userLibraries = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES);
		NSString * pathToLaunchAgents = [[userLibraries objectAtIndex:0] stringByAppendingPathComponent: @"LaunchAgents"];
		NSFileManager * fileManager = [NSFileManager defaultManager];		
		if (! [fileManager fileExistsAtPath:pathToLaunchAgents]) {
			//create launchagents directory:  **TODO: does it need special permissions?
			if (! [fileManager createDirectoryAtPath:pathToLaunchAgents attributes:nil]) {
				return NO;
			}
		}
		NSString *filename = [NSString stringWithFormat:@"com.yarg.%@.plist", [jobName stringWithoutSpaces]];
		// savePath = ~/Library/LaunchAgents/com.yarg.JOBNAME.plist
		NSString *savePath = [pathToLaunchAgents stringByAppendingPathComponent:filename];
		// if jobname changed after file save, delete old file!
		if ([self pathToPlist] != nil && [savePath compare:[self pathToPlist]] != NSOrderedSame){
			if (! [self deleteLaunchdPlist]) // can't delete old file!?
				return NO;
		}
		if (! [[self asLaunchdPlistDictionary] writeToFile:savePath atomically:YES]) {
			return NO;
		}
		// remember where the job is saved now
		[self setPathToPlist:savePath];
	}
	return YES;
}
/*! Deletes the launchd plist associated with this job if it exists.
 *  Returns YES on success and NO if the file does not exist or cannot be deleted.
 */
- (BOOL)deleteLaunchdPlist {
	NSLog(@"deleting job %@ which is at %@", [self jobName], [self pathToPlist]);
	if ([self pathToPlist] != nil && ![[NSFileManager defaultManager] removeFileAtPath:[self pathToPlist] handler:nil]) {
		return NO;
	} else
		return YES;
}



- (NSString *)pathFrom {
	return pathFrom;
}

- (NSString *)pathTo {
	return pathTo;
}

- (NSString *)jobName {
	return jobName;
}

- (NSString *)rsyncPath {
	return rsyncPath;
}

- (NSString *)pathToPlist {
	return pathToPlist;
}
- (void)setPathToPlist:(NSString *)path {
	[pathToPlist autorelease];
	pathToPlist = [path copy];
}

- (unsigned char)dayOfWeek {
	return dayOfWeek;
}

- (void)setDayOfWeek:(unsigned char)day {
	dayOfWeek = day;
}

- (NSDateComponents *)timeOfJob{
	NSDateComponents *timeOfJob = [[NSDateComponents alloc] init];
	[timeOfJob setHour:hourOfDay];
	[timeOfJob setMinute:minuteOfHour];
	return [timeOfJob autorelease];
}

- (void)setTimeOfJob:(NSDateComponents *)date {
	hourOfDay = [date hour];
	minuteOfHour = [date minute];
}

-(void)setRsyncPath:(NSString *)path {
	[rsyncPath autorelease];
	rsyncPath = [path copy];
}

- (void)setPathFrom:(NSString *)path {
	[pathFrom autorelease];
	pathFrom = [path copy];
}

- (void)setPathTo:(NSString *)path {
	[pathTo autorelease];
	pathTo = [path copy];
}

- (void)setJobName:(NSString *)name {
	[jobName autorelease];
	jobName = [name copy];
}

- (BOOL)scheduled {
	return scheduled;
}
- (void)setScheduled:(BOOL)yesno {
	scheduled = yesno;
}

- (BOOL)copyExtended {
	return copyExtended;
}
- (void)setCopyExtended:(BOOL)yesno {
	copyExtended = yesno;
}
- (BOOL)deleteChanged {
	return deleteChanged;
}
- (void)setDeleteChanged:(BOOL)yesno {
	deleteChanged = yesno;
}
- (BOOL)copyHidden {
	return copyHidden;
}
- (void)setCopyHidden:(BOOL)yesno {
	copyHidden = yesno;
}

- (NSMutableArray *)excludeList {
	return excludeList;
}

- (void)setExcludeList:(NSArray *)list {
	[excludeList autorelease];
	excludeList = [[NSMutableArray arrayWithArray:list] retain];
}

- (NSArray *)rsyncArguments {
	NSMutableArray * rsyncArgs = [NSMutableArray arrayWithCapacity: 8];
	[rsyncArgs addObject:@"-ax"]; // add -P when I can parse it into a progress bar
#ifdef IS_DEVELOPMENT
	[rsyncArgs addObject:@"-vv"];
	[rsyncArgs addObject:@"--rsh=ssh -vv"];
#endif
	
	if (copyExtended) {
		[rsyncArgs addObject:@"-E"];
	}
	if (!copyHidden) {
		[rsyncArgs addObject:@"--exclude=.*"];
	}
	if (deleteChanged) {
		[rsyncArgs addObject:@"--delete"];
		[rsyncArgs addObject:@"--delete-excluded"];
	}
	NSArray *thingsToExclude;
	if ([excludeList count] > 0 && (! [[excludeList objectAtIndex:0] isEqual:@""])) {
		thingsToExclude = excludeList;
	} else {
		thingsToExclude = [[[NSUserDefaults standardUserDefaults] objectForKey:
			@"defaultExcludeList"] componentsSeparatedByString:@" "];
	}
	NSEnumerator *excludeEnumerator = [thingsToExclude objectEnumerator];
	NSString *nextItem;
	while ((nextItem = [excludeEnumerator nextObject]))
		if (![nextItem isEqual:@""])
			[rsyncArgs addObject:[@"--exclude=" stringByAppendingString:nextItem]];
	[rsyncArgs addObject: pathFrom];
	[rsyncArgs addObject: pathTo];
	return rsyncArgs;
}



- (void) dealloc
{
	[pathFrom release];
	[pathTo release];
	[jobName release];
	[rsyncPath release];
	[excludeList release];
	[super dealloc];
}

@end
