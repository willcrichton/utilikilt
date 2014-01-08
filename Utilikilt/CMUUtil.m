//
//  CMUUtil.m
//  Utilikilt
//
//  Created by Will Crichton on 1/6/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import "CMUUtil.h"

@implementation CMUUtil

+ (NSString*)truncate:(NSString*)str toLength:(NSInteger)length {
    if ([str length] > length - 3) {
        return [[str substringToIndex:(length-4)] stringByAppendingString:@"..."];
    }
    return str;
}

@end