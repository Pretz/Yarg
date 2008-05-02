//
//  Job.h
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

#import <Cocoa/Cocoa.h>
#import "additions.h"

@interface Job : NSObject 
{
	NSString *pathFrom;
	NSString *pathTo;
	NSString *jobName;
	NSString *rsyncPath;
	NSString *pathToPlist;
	// For launchd:
    NSArray *daysToRun;
	int hourOfDay;
	int minuteOfHour;
	/* rsync orguments for user options: */
	BOOL copyExtended;
	BOOL runAsRoot;
	BOOL copyHidden;
	BOOL deleteChanged;
	int scheduleStyle;
	NSMutableArray *excludeList;

}
+ (Job *)jobFromPlist:(NSString*)pathToPlist;
+ (Job *)jobFromDict:(NSDictionary *)dict;
- (id)initWithPathFrom:(NSString *)path1 
			 pathTo:(NSString *)path2
			   jobName:(NSString *)name;
- (NSString *)pathFrom;
- (NSString *)pathTo;
- (NSString *)jobName;
- (NSString *)rsyncPath;
- (int)scheduleStyle;
- (NSString *)pathToPlist;
- (void)setPathToPlist:(NSString *)path;
- (void)setScheduleStyle:(int)sched;
- (NSArray *)daysToRun;
- (NSDateComponents *)timeOfJob;
- (void)setTimeOfJob:(NSDateComponents *)dateComponents;
- (void)setDaysToRun:(NSArray *)days;
- (void)setPathFrom:(NSString *)path;
- (void)setPathTo:(NSString *)path;
- (void)setJobName:(NSString *)name;
- (void)setRsyncPath:(NSString *)path;
- (NSMutableArray *)excludeList;
- (void)setExcludeList:(NSArray *)list;
- (BOOL)writeLaunchdPlist;
- (BOOL)deleteLaunchdPlist;
- (BOOL)copyExtended;
- (void)setCopyExtended:(BOOL)yn;
- (BOOL)deleteChanged;
- (void)setDeleteChanged:(BOOL)yn;
- (BOOL)copyHidden;
- (void)setCopyHidden:(BOOL)yn;
- (BOOL)runAsRoot;
- (void)setRunAsRoot:(BOOL)yn;
- (NSArray *)rsyncArguments;
- (NSDictionary *)asLaunchdPlistDictionary;
- (NSDictionary *)asSerializedDictionary;
@end

typedef enum _YGScheduleStyle {
    ScheduleNone = 0,
    ScheduleWeekly = 1,
    ScheduleMonthly = 2
} YGScheduleStyle;