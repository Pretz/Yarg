//
//  main.m
//  yarg
//
//  Created by Alex Pretzlav on 11/9/06.
/*  Copyright 2006-2008 Alex Pretzlav. All rights reserved.

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

#import "Common.h"

AuthorizationRef gAuth;

int main(int argc, char *argv[])
{
    
    OSStatus    junk;
    
    // Create the AuthorizationRef that we'll use through this application.
    junk = AuthorizationCreate(NULL, NULL, kAuthorizationFlagDefaults, &gAuth);
    assert(junk == noErr);
    assert( (junk == noErr) == (gAuth != NULL) );
    
    // For each of our commands, check to see if a right specification 
    // exists and, if not, create it. 
    BASSetDefaultRules(
                       gAuth, 
                       kYargCommandSet, 
                       CFBundleGetIdentifier(CFBundleGetMainBundle()), 
                       NULL
                       );
    
    return NSApplicationMain(argc,  (const char **) argv);
}
