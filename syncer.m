//
//  syncer.m
//  yarg
//
//  Created by Alex Pretzlav on 6/5/07.
//  Copyright 2007 Alex Pretzlav. All rights reserved.

#import "syncer.h"
#include <stdio.h>
#import <Foundation/Foundation.h>

int main(int argc, char *argv[])
{
	if (argc != 2) {
		fprintf(stderr, "usage: %s JOBNAME\n", argv[0]);
		return 10;
	}
	// Evidently creating this pool lets all of Cocoa know where to find it
	NSAutoreleasePool *thePool = [[NSAutoreleasePool alloc] init];
	// load preferences file
	// NOTE: is there a more sane way to do this?
	NSUserDefaults *myDefaults = [NSUserDefaults standardUserDefaults];
	NSString *myJobName = [NSString stringWithUTF8String:argv[1]];
	//NSLog(@"I would load %@, i have %d args", [NSString stringWithUTF8String:argv[1]], argc);
	//NSLog(@"i hope this works: %@", [myDefaults objectForKey:@"Jobs"]);
	NSDictionary * jobDict;
	if (! (jobDict = [[myDefaults objectForKey:@"Jobs"] objectForKey:myJobName])) {
		fprintf(stderr, "No job called \"%s\" found\n", argv[1]);
		return 11;
	}
	NSLog(@"running rsync %@", rsyncArgumentsFromDict(jobDict));
	NSLog(@"this job is %@", jobDict);
	// Release autorelease pool
	[thePool release];
    return 0;
}

BOOL runThisJob(NSDictionary * dict) {
	NSTask *rsync = [[NSTask alloc] init];
	// TODO: Only store "Program" if set for individual job, otherwise
	// use global program rsync path.
	[rsync setLaunchPath:[dict objectForKey:@"Program"]];
	[rsync setArguments:[rsyncArgumentsFromDict(dict) arrayByAddingObject:@"--no-detach"];
	[rsync launch];
	[rsync waitUntilExit];
	if ([rsync terminationStatus] != 0) {
		NSLog(@"running job %@ failed", [dict objectForKey:@"jobName"]);
		return NO;
	}
	return YES;
}

NSArray * rsyncArgumentsFromDict(NSDictionary *dict) {
	NSMutableArray * rsyncArgs = [NSMutableArray arrayWithCapacity: 8];
	[rsyncArgs addObject:@"-ax"];
#ifdef IS_DEVELOPMENT
	[rsyncArgs addObject:@"-vv"];
	[rsyncArgs addObject:@"--rsh=ssh -vv"];
#endif
	[rsyncArgs addObject:@"--delete-excluded"];
	
	if ([dict objectForKey:@"copyExtended"]) {
		[rsyncArgs addObject:@"-E"];
	}
	if (![dict objectForKey:@"copyHidden"]) {
		[rsyncArgs addObject:@"--exclude=.*"];
	}
	if ([dict objectForKey:@"deleteChanged"]) {
		[rsyncArgs addObject:@"--delete"];
	}
	NSArray *thingsToExclude;
	NSArray *excludeList = [dict objectForKey:@"excludeList"];
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
	[rsyncArgs addObject: [dict objectForKey:@"pathFrom"]];
	[rsyncArgs addObject: [dict objectForKey:@"pathTo"]];
	return rsyncArgs;
}