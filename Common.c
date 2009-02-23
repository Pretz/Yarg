/*
 *  Common.c
 *  yarg
 *
 *  Created by Alex Pretzlav on 4/28/08.
 *  Copyright 2008 Alex Pretzlav. All rights reserved.
 *
 */

#include "Common.h"

const BASCommandSpec kYargCommandSet[] = {
    {	kRunRsyncCommand,                       // commandName
        kRunRsyncCommandRightName,              // rightName           -- never authorize
        "default",                              // rightDefaultRule	   -- not applicable if rightName is NULL
        NULL,									// rightDescriptionKey -- not applicable if rightName is NULL
        NULL                                    // userData
	},
    
    {
        kStopRsyncCommand,
        kStopRsyncCommandRightName,
        "default",
        NULL,
        NULL
    },
    
    {	kWriteLaunchdJobCommand,                // commandName
        kWriteLaunchdJobCommandRightName,        // rightName
        "default",                              // rightDefaultRule
        "WriteLaunchdPasswordPrompt",
        NULL                                    // userData
	},
    
    {	kDeleteLaunchdJobCommand,                // commandName
        kDeleteLaunchdJobCommandRightName,        // rightName
        "default",                              // rightDefaultRule
        NULL,
        NULL                                    // userData
	},
    
    {	NULL,                                   // the array is null terminated
        NULL, 
        NULL, 
        NULL,
        NULL
	}
    
};