//
//  additions.m
//  yarg
//
//  Created by Alex Pretzlav on 11/16/06.
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

#import "additions.h"


@implementation NSString (additions)
- (NSString *)stringWithoutSpaces {
	NSMutableString * strippedString = [NSMutableString stringWithString:@""];
	unichar space = [@" " characterAtIndex:0];
	for (unsigned int x = 0; x < [self length]; x++) {
		if ([self characterAtIndex:x] != space) {
			[strippedString appendFormat:@"%C", [self characterAtIndex:x]];
		}
	}
	return strippedString;
}
- (NSString *)stringByTrimmingWhitespace {
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}
- (NSArray *)componentsSeperatedByCharacterSet:(NSCharacterSet *)aSet {
	NSString * string = self;
	NSMutableArray * anArray = [NSMutableArray array];
	NSRange range = [string rangeOfCharacterFromSet:aSet];
	while (range.location != NSNotFound) {
		[anArray addObject:[string substringToIndex:range.location]];
		string = [string substringFromIndex: range.location+range.length];
		range = [string rangeOfCharacterFromSet:aSet];
	}
	if ([string length] > 0) {
		[anArray addObject:string];
	}
	return anArray;
}
@end


#ifdef IS_DEVELOPMENT
void smartLog(NSString *format, ...) {
	va_list ap;
	va_start(ap, format);

	NSLogv(format, ap);
	va_end(ap);
#else
inline void smartLog(NSString *format, ...) {
#endif
}

NSString *suffixForNum(int num) {
    NSString * suffix;
    if (num < 10 || num > 19) {
        switch (num % 10) {
            case 1:
                suffix = @"st";
                break;
            case 2:
                suffix = @"nd";
                break;
            case 3:
                suffix = @"rd";
                break;
            default:
                suffix = @"th";
        }
    } else {
        suffix = @"th";
    }
    return suffix;
}