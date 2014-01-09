//
//  CMUUtil.h
//  Utilikilt
//
//  Created by Will Crichton on 1/6/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CMUUtil : NSObject
+ (NSString*)truncate:(NSString*)str toLength:(NSInteger)length;
+ (id)load:(NSString*)path;
+ (void)save:(id)obj toPath:(NSString*)path;
@end
