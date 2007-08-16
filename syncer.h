//
//  syncer.h
//  yarg
//
//  Created by Alex Pretzlav on 6/5/07.
//  Copyright 2007 Alex Pretzlav. All rights reserved.
//


NSArray * rsyncArgumentsFromDict(NSDictionary *dict);
BOOL runThisJob(NSDictionary *dict);
pid_t sessionID;