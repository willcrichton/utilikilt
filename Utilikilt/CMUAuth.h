//
//  CMUAuth.h
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CMUAuth : NSObject
@property NSURLSession *session;
+ (void) authenticate:(NSString*)url onAuth:(void (^)(NSURLSession*))handler;
@end
