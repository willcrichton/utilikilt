//
//  CMUUtil.m
//  Utilikilt
//
//  Created by Will Crichton on 1/6/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import "CMUUtil.h"

@implementation CMUUtil

// Truncates a string to the given length and adds an ellipsis (...) if truncated
+ (NSString*)truncate:(NSString*)str toLength:(NSInteger)length {
    if ([str length] > length - 3) {
        return [[str substringToIndex:(length-4)] stringByAppendingString:@"..."];
    }
    return str;
}

+ (id)load:(NSString*)path {
    NSString *abspath = [[NSString alloc] initWithFormat:@"%@/Documents/%@", NSHomeDirectory(), path];
    return [NSKeyedUnarchiver unarchiveObjectWithFile:abspath];
}

+ (void)save:(id)obj toPath:(NSString*)path {
    NSString *abspath = [[NSString alloc] initWithFormat:@"%@/Documents/%@", NSHomeDirectory(), path];
    [NSKeyedArchiver archiveRootObject:obj toFile:abspath];
}

@end
