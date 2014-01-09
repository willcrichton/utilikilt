//
//  CMUAuth.h
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CMUAuth : NSObject
+ (void) authenticate:(NSString*)url onAuth:(void (^)(NSURLSession*))handler;
+ (NSMutableURLRequest*)newRequest:(NSString *)url;
+ (void)loadFinalGrades:(void (^)(BOOL))handler;
+ (void)loadBlackboardGrades:(void (^)(BOOL))handler;
+ (void)loadAutolabGrades:(void (^)(BOOL))handler;
+ (void)loadAllGrades:(void (^)(BOOL))handler;
+ (void)loadSIO:(void (^)(BOOL))handler;
+ (void)getCourseInfo:(NSString*)course withHandler:(void (^)(NSDictionary*))handler;
+ (void)finger:(NSString*)andrew withHandler:(void (^)(NSArray*))handler;
@end