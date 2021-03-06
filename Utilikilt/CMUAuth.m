//
//  CMUAuth.m
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import "CMUAuth.h"
#import "CMUUtil.h"
#import "TFHpple.h"
#import "MXLCalendarManager.h"

/*
 * TODO:
 * Optimize blackboard/autolab by only fetching current (not completed) courses
 * Figure out why/what to do when shit randomly fails
 */

@interface CMUAuth ()
@end

@implementation CMUAuth

+ (NSMutableURLRequest*)newRequest:(NSString *)url {
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                   cachePolicy:NSURLRequestUseProtocolCachePolicy
                               timeoutInterval:60.0];
}

+ (void) authenticate:(NSString*)url onAuth:(void (^)(NSURLSession*))handler {
    
    // create the main session for sending requests
    NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session =
    [NSURLSession sessionWithConfiguration:sessionConfig];
    
    // Step 2 is to find the pieces of the resposne we need for Shibboleth and send 'em to the server
    void (^step2)() = ^(NSData *page, NSURLResponse *response, NSError *error) {
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:page];
    
        // check if authentication failed
        for (TFHppleElement *div in [doc searchWithXPathQuery:@"//div"]) {
            if ([[div objectForKey:@"id"] isEqualToString:@"failed"]) {
                if ([[div text] rangeOfString:@"Authentication failed."].location != NSNotFound) {
                    if (handler != nil) {
                        handler(nil);
                    }
                    return;
                }
            }
        }
        
        TFHppleElement *el = [[doc searchWithXPathQuery:@"//form"] firstObject];
        NSString* action = [el objectForKey:@"action"];
        
        NSString *data = @"a=b";
        NSArray *inputs = [doc searchWithXPathQuery:@"//input"];
        for (TFHppleElement *input in inputs) {
            NSString *name = [input objectForKey:@"name"];
            if ([name isEqualToString:@"submit"] || name.length == 0) continue;
            
            data = [NSString stringWithFormat:@"%@&%@=%@", data, name, [input objectForKey:@"value"]];
        }
        
        NSMutableURLRequest *request = [self newRequest:action];
        data = [data stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];

        // set headers so it seems like a reasonable packet
        [request setValue:@"https://login.cmu.edu" forHTTPHeaderField:@"Origin"];
        [request setValue:@"https://login.cmu.edu/idp/profile/SAML2/Redirect/SSO" forHTTPHeaderField:@"Referer"];
        [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.14 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[NSData dataWithBytes:[data UTF8String] length:strlen([data UTF8String])]];
        [request setHTTPMethod:@"POST"];
        
        // Once the server has given us the proper cookies, we're good to go with the current session
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (handler != nil) {
                handler(session);
            }
        }] resume];
    };
    
    // Step 1 is to send our username/password to the server
    void (^step1)() = ^(NSData *page, NSURLResponse *response, NSError *error) {
        
        // For an unknown reason, despite allocating a new session in each authenticate call,
        // the app appears to be reusing the same session and hence we get auto-login.
        // Here, we check to see if we're already authenticated.
        if ([[[response URL] absoluteString] rangeOfString:@"SAML2"].location != NSNotFound) {
            step2(page, response, error);
            return;
        }
        
        NSMutableURLRequest *request = [self newRequest:@"https://login.cmu.edu/idp/Authn/Stateless"];
        
        [request setValue:@"login.cmu.edu" forHTTPHeaderField:@"Host"];
        [request setValue:@"https://login.cmu.edu/idp/Authn/Stateless" forHTTPHeaderField:@"Referer"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPMethod:@"POST"];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *data = [[NSString alloc] initWithFormat:@"j_username=%@&j_password=%@&j_continue=1&submit=Login",
                          [defaults objectForKey:@"username"], [defaults objectForKey:@"password"]];
        [request setHTTPBody:[NSData dataWithBytes:[data UTF8String] length:strlen([data UTF8String])]];
        
        [[session dataTaskWithRequest:request
                    completionHandler:step2]
         resume];
    };

    NSLog(@"Authenticating to %@", url);
    [[session dataTaskWithURL:[NSURL URLWithString:url]
            completionHandler:step1]
     resume];
}

+ (void)loadFinalGrades:(void (^)(BOOL))handler {
    
    __block NSURLSession *session;
    
    // Step 2 is to get the HTML content of the audit for main major and scrape the grades
    void (^step2)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Final grades: step 2");
        
        // extract grades from academic audit page
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        NSMutableArray *grades = [[NSMutableArray alloc] init];
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//pre"]) {
            for (NSString* line in [[el text] componentsSeparatedByString:@"\n"]) {
                NSRegularExpression *regex =
                [NSRegularExpression regularExpressionWithPattern:@"(\\d+-\\d+) (\\w+)\\s*\\'(\\d+) ((\\w|\\*)+)\\s*(\\d+\\.\\d)\\s*$"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
                NSArray *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
                for (NSTextCheckingResult *match in matches) {
                    NSString *grade = [line substringWithRange:[match rangeAtIndex:4]];
                    
                    if (![grade isEqualToString:@"*"]) {
                        [grades addObject:@{@"course":[line substringWithRange:[match rangeAtIndex:1]],
                                            @"grade":grade,
                                            @"semester":[line substringWithRange:[match rangeAtIndex:2]],
                                            @"year":[line substringWithRange:[match rangeAtIndex:3]]
                                            }];
                    }
                }
            }
        }
        
        // sort in ascending order by course name
        [grades sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSComparisonResult yearCmp = [obj2[@"year"] caseInsensitiveCompare:obj1[@"year"]],
            semesterCmp = [obj1[@"semester"] caseInsensitiveCompare:obj2[@"semester"]],
            nameCmp = [obj1[@"course"] caseInsensitiveCompare:obj2[@"course"]];
            
            if (yearCmp == NSOrderedSame) {
                if (semesterCmp == NSOrderedSame) {
                    return nameCmp;
                } else {
                    return semesterCmp;
                }
            } else {
                return yearCmp;
            }
        }];
        
        //store the array
        NSArray *oldGrades = [CMUUtil load:@"final_grades"];
        [CMUUtil save:grades toPath:@"final_grades"];
      
        // Show local notification for any changed grades
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        if ([oldGrades count] != 0 &&
            ![[defaults objectForKey:@"grade_notifications"] isEqualToNumber:[NSNumber numberWithBool:NO]]) {
            for (NSDictionary *grade in grades) {
                for (NSDictionary *oldGrade in oldGrades) {
                    if (![grade[@"course"] isEqualToString:oldGrade[@"course"]] ||
                        [grade[@"grade"] isEqualToString:oldGrade[@"grade"]]) continue;
                    
                    UILocalNotification *note = [[UILocalNotification alloc] init];
                    note.fireDate = [NSDate date];
                    note.alertBody = [[NSString alloc] initWithFormat:@"New final grade for %@: %@",
                                      grade[@"course"], grade[@"grade"]];
                    [[UIApplication sharedApplication] scheduleLocalNotification:note];
                }
            }
        }
        
        if (handler != nil) {
            handler(YES);
        }
    };
    
    // Step 1 is to get the options page of academic audit and determine our main major
    void (^step1)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Final grades: step 1");
        
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        NSString *newUrl = @"https://enr-apps.as.cmu.edu/audit/audit?call=7";
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//input"]) {
            if (![[el objectForKey:@"type"] isEqualToString:@"hidden"] ||
                [[el objectForKey:@"name"] isEqualToString:@"call"]) continue;
            newUrl = [newUrl stringByAppendingFormat:@"&%@=%@", [el objectForKey:@"name"], [el objectForKey:@"value"]];
        }
        
        newUrl = [newUrl stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        [[session dataTaskWithRequest:[self newRequest:newUrl] completionHandler:step2] resume];
    };
    
    [CMUAuth authenticate:@"https://enr-apps.as.cmu.edu/audit/audit" onAuth:^(NSURLSession *s){
        if (s == nil) {
            if (handler != nil) {
                handler(NO);
            }
            return;
        }
        
        NSMutableURLRequest *request =
            [self newRequest:@"https://enr-apps.as.cmu.edu/audit/audit?call=2"];
        
        session = s;
        
        [[session dataTaskWithRequest:request
                    completionHandler:step1
         ] resume];
    }];
}

+ (void)loadBlackboardGrades:(void (^)(BOOL))handler {
    
    __block NSURLSession *session;
    
    NSMutableArray *grades = [[NSMutableArray alloc] init];
    NSLock *lock = [[NSLock alloc] init];
    
    // Note: for this and Autolab, the "step1/step2" is just following my convention.
    // There's actually many step2 calls for every course that we evaluate. Surprise!
    
    // Step 2 is to scrape a course's grades off of its blackboard page
    void (^step2)() = ^(NSData *data, NSString *course) {
        NSMutableArray *hws = [[NSMutableArray alloc] init];
        
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        NSString *hw;
        
        // do we actually need a lock on the MutableArray? not sure. is it thread safe? probably not
        [lock lock];
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//div"]) {
            NSString *class = [el objectForKey:@"class"];
            NSString *text = [[el text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([class isEqualToString:@"name"]) {
                hw = text;
            } else if ([class rangeOfString:@"gradeCellGrade"].location != NSNotFound) {
                NSString *grade = text;
                
                NSArray *children = [el childrenWithClassName:@"outof"];
                if ([children count] > 0 && ![hw isEqualToString:@""]) {
                    NSString *total = [[children[0] text] substringFromIndex:1];
                    [hws addObject:@{@"name": hw,
                                     @"grade":[[NSString alloc] initWithFormat:@"%@/%@", grade, total]}];
                }
            }
        }
        
        if ([hws count] > 0) {
            [grades addObject:@{@"course": course, @"hws": hws}];
        }
        [lock unlock];
    };
    
    // Step 1 is to get the list of courses the user is taking on blackboard
    void (^step1)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Blackboard grades: querying...");
        
        NSDictionary *bbGrades = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:kNilOptions
                                                                   error:&error];
        
        if ([bbGrades[@"sv_extras"][@"sx_filters"] count] == 0) {
            NSLog(@"Blackboard grades: failed.");
            if (handler != nil) {
                handler(NO);
            }
            return;
        }
        
        dispatch_group_t group = dispatch_group_create();
        
        NSDictionary *bbCourses = bbGrades[@"sv_extras"][@"sx_filters"][0][@"choices"];
        for (NSString *cid in bbCourses) {
            NSString *course = bbCourses[cid];
            
            NSMutableURLRequest *request =
            [self newRequest:[[NSString alloc] initWithFormat:@"https://blackboard.andrew.cmu.edu/webapps/bb-mygrades-BBLEARN/myGrades?course_id=%@&stream_name=mygrades", cid]];
            
            dispatch_group_enter(group);
            [[session dataTaskWithRequest:request
                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            step2(data, course);
                            dispatch_group_leave(group);
                        }]
             resume];

        }
        
        // once all our results are combined, sort/save the results
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSLog(@"Blackboard grades: finished querying.");
            
            NSArray* (^getParts)(NSString*) = ^NSArray*(NSString *str) {
                return @[[str substringToIndex:1], [str substringWithRange:NSMakeRange(1, 2)],
                         [str substringFromIndex:3]];
            };
            
            [grades sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                NSArray *course1 = getParts(obj1[@"course"]), *course2 = getParts(obj2[@"course"]);
                NSComparisonResult yearCmp = [course2[1] caseInsensitiveCompare:course1[1]],
                semesterCmp = [course2[0] caseInsensitiveCompare:course1[0]],
                nameCmp = [course2[2] caseInsensitiveCompare:course1[2]];
                
                if (yearCmp == NSOrderedSame) {
                    if (semesterCmp == NSOrderedSame) {
                        return nameCmp;
                    } else {
                        return semesterCmp;
                    }
                } else {
                    return yearCmp;
                }
            }];
            
            NSArray *oldGrades = [CMUUtil load:@"blackboard_grades"];
            [CMUUtil save:grades toPath:@"blackboard_grades"];

            // i hate myself for this code O(n^2) code block
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            if ([oldGrades count] != 0 &&
                ![[defaults objectForKey:@"grade_notifications"] isEqualToNumber:[NSNumber numberWithBool:NO]]) {
                for (NSDictionary *course in grades) {
                    for (NSDictionary *oldCourse in oldGrades) {
                        if ([oldCourse[@"course"] isEqualToString:course[@"course"]]) {
                            for (NSDictionary *hw in course[@"hws"]) {
                                BOOL isNew = YES;
                                for (NSDictionary *oldHW in oldCourse[@"hws"]) {
                                    if ([hw[@"name"] isEqualToString:oldHW[@"name"]]) {
                                        isNew = ![hw[@"grade"] isEqualToString:oldHW[@"grade"]];
                                    }
                                }
                                
                                if (isNew) {
                                    UILocalNotification *note = [[UILocalNotification alloc] init];
                                    note.fireDate = [NSDate date];
                                    note.alertBody = [[NSString alloc] initWithFormat:@"New Blackboard grade for %@ (%@): %@",
                                                      [CMUUtil truncate:hw[@"name"] toLength:40],
                                                      [CMUUtil truncate:course[@"course"] toLength:40],
                                                      hw[@"grade"]];
                                    [[UIApplication sharedApplication] scheduleLocalNotification:note];

                                }
                            }
                        }
                    }
                    
                }
            }
            
            handler(YES);
        });
    };
    
    [CMUAuth authenticate:@"https://blackboard.andrew.cmu.edu" onAuth:^(NSURLSession *s){
        if (s == nil) {
            if (handler != nil) {
                handler(NO);
            }
            return;
        }
        
        NSMutableURLRequest *request =
        [self newRequest:@"https://blackboard.andrew.cmu.edu/webapps/streamViewer/streamViewer"];
        
        NSString *data = @"cmd=loadStream&streamName=mygrades&providers=%7B%7D&forOverview=false";
        [request setHTTPBody:[NSData dataWithBytes:[data UTF8String] length:strlen([data UTF8String])]];
        [request setHTTPMethod:@"POST"];
        
        session = s;
        
        [[session dataTaskWithRequest:request
                    completionHandler:step1
          ] resume];
    }];
}

+ (void)loadAutolabGrades:(void (^)(BOOL))handler {
    
    __block NSURLSession *session;
    
    NSMutableArray *grades = [[NSMutableArray alloc] init];
    NSLock *lock = [[NSLock alloc] init];
    
    // This is basically the same process as getting Blackboard grades,
    // except the URLs change and the scraping is a little different.
    
    void (^step2)() = ^(NSData *data, NSString *course) {
        NSMutableArray *hws = [[NSMutableArray alloc] init];
        
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        
        NSString *hw;
        [lock lock];
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//tr/td[1]//a | //tr/td[last()]"]) {
            if ([[el tagName] isEqualToString:@"a"]) {
                hw = [[el text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else {
                NSString *grade = [[NSString alloc] initWithFormat:@"%@/%@",
                                   [[[el childrenWithTagName:@"a"] firstObject] text],
                                   [[[el childrenWithTagName:@"span"] firstObject] text]];
                
                if ([[[el childrenWithTagName:@"a"] firstObject] text] != nil &&
                     [[[el childrenWithTagName:@"span"] firstObject] text] != nil &&
                    ![hw isEqualToString:@""]) {
                    [hws addObject:@{@"name": hw, @"grade": grade}];
                }
            }
        }
        
        if ([hws count] > 0) {
            [grades addObject:@{@"course": course, @"hws": hws}];
        }
        [lock unlock];
    };
    
    void (^step1)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Autolab grades: querying...");
        
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        dispatch_group_t group = dispatch_group_create();
        
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//li"]) {
            TFHppleElement *link = [[el childrenWithTagName:@"a"] lastObject];
            NSString *course = [link text];
            NSString *url = [[NSString alloc] initWithFormat:@"https://autolab.cs.cmu.edu%@/gradebook/student",
                             [link objectForKey:@"href"]];
            
            dispatch_group_enter(group);
            [[session dataTaskWithRequest:[self newRequest:url]
                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            step2(data, course);
                            dispatch_group_leave(group);
                        }]
             resume];
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSLog(@"Autolab grades: finished queries.");
            
            [grades sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                return [obj2[@"course"] caseInsensitiveCompare:obj1[@"course"]];
            }];
            
            NSArray *oldGrades = [CMUUtil load:@"autolab_grades"];
            [CMUUtil save:grades toPath:@"autolab_grades"];
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            
            if ([oldGrades count] != 0 &&
                ![[defaults objectForKey:@"grade_notifications"] isEqualToNumber:[NSNumber numberWithBool:NO]]) {
                for (NSDictionary *course in grades) {
                    for (NSDictionary *oldCourse in oldGrades) {
                        if ([oldCourse[@"course"] isEqualToString:course[@"course"]]) {
                            for (NSDictionary *hw in course[@"hws"]) {
                                BOOL isNew = YES;
                                for (NSDictionary *oldHW in oldCourse[@"hws"]) {
                                    if ([hw[@"name"] isEqualToString:oldHW[@"name"]]) {
                                        isNew = ![hw[@"grade"] isEqualToString:oldHW[@"grade"]];
                                    }
                                }
                                
                                if (isNew) {
                                    UILocalNotification *note = [[UILocalNotification alloc] init];
                                    note.fireDate = [NSDate date];
                                    note.alertBody = [[NSString alloc] initWithFormat:@"New Autolab grade for %@ (%@): %@",
                                                      [CMUUtil truncate:hw[@"name"] toLength:40],
                                                      [CMUUtil truncate:course[@"course"] toLength:40],
                                                      hw[@"grade"]];
                                    [[UIApplication sharedApplication] scheduleLocalNotification:note];
                                    
                                }
                            }
                        }
                    }
                    
                }
            }

            
            if (handler != nil) {
                handler(YES);
            }
        });
    };
    
    [CMUAuth authenticate:@"https://autolab.cs.cmu.edu" onAuth:^(NSURLSession *s){
        if (s == nil) {
            if (handler != nil) {
                handler(NO);
            }
            return;
        }
        
        session = s;
        
        [[session dataTaskWithRequest:[self newRequest:@"https://autolab.cs.cmu.edu"]
                    completionHandler:step1
          ] resume];
    }];
}

+ (void)loadAllGrades:(void (^)(BOOL))handler {
    [CMUAuth authenticate:@"https://s3.as.cmu.edu/sio/index.html"
     onAuth:^(NSURLSession *session) {
         if (session == nil) {
             if (handler != nil) {
                 handler(NO);
             }
             return;
         }
         
         dispatch_group_t group = dispatch_group_create();
         dispatch_group_enter(group);
         [CMUAuth loadFinalGrades:^(BOOL b) {
             dispatch_group_leave(group);
         }];
         
         dispatch_group_enter(group);
         [CMUAuth loadBlackboardGrades:^(BOOL b) {
             dispatch_group_leave(group);
         }];
         
         dispatch_group_enter(group);
         [CMUAuth loadAutolabGrades:^(BOOL b) {
             dispatch_group_leave(group);
         }];
         
         dispatch_group_enter(group);
         [CMUAuth loadSIO:^(BOOL b) {
             dispatch_group_leave(group);
         }];
         
         dispatch_group_notify(group, dispatch_get_main_queue(), ^{
             if (handler != nil) {
                 handler(YES);
             }
         });
     }];
}

// helper functions for getting SIO datas //

// shorthand for parsing a string w/ regex
+ (NSArray*)getMatches:(NSString*)string withPattern:(NSString*)pattern {
    NSError *error;
    NSRegularExpression *regex =
    [NSRegularExpression regularExpressionWithPattern:pattern
                                              options:kNilOptions
                                                error:&error];
    return [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
}

// turn a GWT RPC (Google Web Toolkit + Remote Procedure Call) response into JSON
+ (NSArray*)parseGWT:(NSData*)data {
    NSError *error;
    NSString *output = [[[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
                         substringFromIndex:4] stringByReplacingOccurrencesOfString:@"'" withString:@"\""]
                          stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    return [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:kNilOptions
                                                      error:&error];
}

+ (NSString*)getKey:(NSString*)rpc inPage:(NSString*)page {
    NSArray *matches = [self getMatches:page withPattern:[[NSString alloc] initWithFormat:@"'%@',(\\w+),", rpc]];
    matches = [self getMatches:page withPattern:[[NSString alloc] initWithFormat:@"%@='([^']+)'",
                                                 [page substringWithRange:[matches[0] rangeAtIndex:1]]]];
    return [page substringWithRange:[matches[0] rangeAtIndex:1]];
}

+ (void)loadSIO:(void (^)(BOOL))handler {
    __block NSURLSession *session;
    __block NSDictionary *dayMap = @{@"MO": @1, @"TU": @2, @"WE": @3, @"TH": @4, @"FR": @5};
    
    // here we do the gruntwork: do all the RPC calls, extract the necessary data
    void (^step3)() = ^(NSString *content_key, NSString *finances_key) {
        
        NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
        NSLock *lock = [[NSLock alloc] init];
        dispatch_group_t group = dispatch_group_create();
        
        // SMC + mailbox combo
        NSMutableURLRequest *request = [self newRequest:@"https://s3.as.cmu.edu/sio/sio/bioinfo.rpc"];
        NSString *body = [[NSString alloc] initWithFormat:@"7|0|4|https://s3.as.cmu.edu/sio/sio/|%@|edu.cmu.s3.ui.sio.student.client.serverproxy.bio.StudentBioService|fetchStudentSMCBoxInfo|1|2|3|4|0|", content_key];
        [request setHTTPBody:[NSData dataWithBytes:[body UTF8String] length:strlen([body UTF8String])]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"text/x-gwt-rpc; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        
        dispatch_group_enter(group);
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSArray *json = [self parseGWT:data];
            
            [lock lock];
            info[@"smc"] = [NSString stringWithFormat:@"%@", json[5][2]];
            info[@"mailbox"] = [NSMutableString stringWithFormat:@"%@", json[5][1]];
            [info[@"mailbox"] insertString:@"-" atIndex:4];
            [info[@"mailbox"] insertString:@"-" atIndex:2];
            [lock unlock];
            
            dispatch_group_leave(group);
        }] resume];
        
        
        // Student ID + card number
        body = [[NSString alloc] initWithFormat:@"7|0|4|https://s3.as.cmu.edu/sio/sio/|%@|edu.cmu.s3.ui.sio.student.client.serverproxy.bio.StudentBioService|fetchStudentCardInfo|1|2|3|4|0|", content_key];
        [request setHTTPBody:[NSData dataWithBytes:[body UTF8String] length:strlen([body UTF8String])]];
        
        dispatch_group_enter(group);
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSArray *json = [self parseGWT:data];
            
            [lock lock];
            info[@"card_id"] = json[5][1];
            // fun fact: json[5][3], or your student ID, is your SSN.
            // probably don't want to display that
            [lock unlock];
            
            dispatch_group_leave(group);
        }] resume];
        
        
        // Schedule
        [request setURL:[NSURL URLWithString:@"https://s3.as.cmu.edu/sio/export/schedule/S14_semester.ics?semester=S14"]];
        
        dispatch_group_enter(group);
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            MXLCalendarManager *manager = [[MXLCalendarManager alloc] init];
            [manager parseICSString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
              withCompletionHandler:^(MXLCalendar *calendar, NSError *err) {
                  [lock lock];
                  info[@"schedule"]     = [[NSMutableArray alloc] init];
                  
                  for (MXLCalendarEvent *event in calendar.events) {
                      // event.eventSummary is "Course Name :: ##### A/B"
                      // event.eventLocation is "CODE - ROOM"
                      
                      NSArray *days = [[[event.rruleString componentsSeparatedByString:@"="] lastObject]
                                       componentsSeparatedByString:@","];
                      
                      NSMutableArray *dayNums = [[NSMutableArray alloc] init];
                      for (NSString *day in days) {
                          [dayNums addObject:dayMap[day]];
                      }
                      
                      NSString *location = [event.eventLocation stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                      
                      NSString *summary = [event.eventSummary stringByReplacingOccurrencesOfString:@"\\" withString:@""];
                      
                      [info[@"schedule"] addObject:@{@"name": summary,
                                                     @"location": location,
                                                     @"days": dayNums,
                                                     @"start_time": event.eventStartDate,
                                                     @"end_time": event.eventEndDate}];
                  }
                  [lock unlock];
                  
                  dispatch_group_leave(group);
              }];
        }] resume];
       
        /*** TODO: figure out finances 
         
        [request setURL:[NSURL URLWithString:@"https://s3.as.cmu.edu/sio/sio/finances.rpc"]];
        body = [[NSString alloc] initWithFormat:@"7|0|4|https://s3.as.cmu.edu/sio/sio/|%@|edu.cmu.s3.ui.sio.student.client.serverproxy.finances.FinancesService|fetchBillingTransactionDTOs|1|2|3|4|0|", finances_key];
        [request setHTTPBody:[NSData dataWithBytes:[body UTF8String] length:strlen([body UTF8String])]];
        
        dispatch_group_enter(group);
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSArray *json = [self parseGWT:data];
            NSMutableArray *finances = [[NSMutableArray alloc] initWithArray:json[[json count] - 3]];
            
            NSRegularExpression *badRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\d+$" options:kNilOptions error:&error];
            NSMutableArray *toDiscard = [[NSMutableArray alloc] init];
            for (int i = 0; i < [finances count]; i++) {
                NSString *entry = finances[i];
                NSRange java = [entry rangeOfString:@"java"];
                if (java.location != NSNotFound ||
                    [badRegex numberOfMatchesInString:entry options:kNilOptions range:NSMakeRange(0, [entry length])] > 0) {
                    [toDiscard addObject:entry];
                }
            }
            
            [finances removeObjectsInArray:toDiscard];
            
            NSLog(@"%@", finances);
            
            NSRegularExpression *isCode = [NSRegularExpression regularExpressionWithPattern:@"^\\w{3}\\d$" options:kNilOptions error:&error];
            
            NSRegularExpression *isNum = [NSRegularExpression regularExpressionWithPattern:@"^-?\\d+\\.\\d+$" options:kNilOptions error:&error];
            
            // if on 4 letter code exists negative number, ignore
            // when see negative number, check if $$ exists, else scan up until find nonempty string (trimmed)
            
            NSMutableArray *final = [[NSMutableArray alloc] init];
            NSMutableDictionary *priceMap = [[NSMutableDictionary alloc] init];
            
            for (int i = 3; i < [finances count] - 2; i++) {
                NSString *entry = finances[i];
               
                if ([isCode numberOfMatchesInString:entry options:kNilOptions range:NSMakeRange(0, [entry length])] > 0) {
                    if ([[finances[i + 2] substringFromIndex:1] isEqualToString:finances[i+1]] ) continue;
                    priceMap[finances[i+1]] = finances[i-1];
                    NSLog(@"Standard: %@ %@", finances[i-1], finances[i+1]);
                    [final addObject:@{@"name": finances[i-1], @"cost": finances[i+1]}];
                }
                
                if ([[entry substringToIndex:1] isEqualToString:@"-"]) {
                    NSString *name = priceMap[[entry substringFromIndex:1]];
                    if (name != nil) {
                        [final addObject:@{@"name": name, @"cost": entry}];
                        NSLog(@"Mapped: %@ %@", name, entry);
                    } else {
                        for (int j = i - 1; j >= 0; j--) {
                            NSString *oldName = [finances[j] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            if (![oldName isEqualToString:@""] &&
                                [isNum numberOfMatchesInString:oldName options:kNilOptions range:NSMakeRange(0, [oldName length])] == 0 &&
                                [isCode numberOfMatchesInString:oldName options:kNilOptions range:NSMakeRange(0, [oldName length])] == 0) {
                                [final addObject:@{@"name": oldName, @"cost": entry}];
                                NSLog(@"Scanned: %@ %@", oldName, entry);
                                break;
                            }
                        }
                    }
                }
            }
            
            NSLog(@"%@", final);
            
            dispatch_group_leave(group);
        }] resume];
        ***/
        
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [CMUUtil save:info toPath:@"sio_info"];
            if (handler != nil) {
                handler(YES);
            }
        });
    };
    
    // Find our various RPC keys within the document and set up system by querying userContext.rpc
    void (^step2)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *page = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        NSString *context_key = [self getKey:@"userContext.rpc" inPage:page],
        *content_key = [self getKey:@"bioinfo.rpc" inPage:page],
        *finances_key = [self getKey:@"finances.rpc" inPage:page];
        
        NSMutableURLRequest *request = [self newRequest:@"https://s3.as.cmu.edu/sio/sio/userContext.rpc"];
        NSString *body = [[NSString alloc] initWithFormat:@"7|0|4|https://s3.as.cmu.edu/sio/sio/|%@|edu.cmu.s3.ui.common.client.serverproxy.user.UserContextService|initUserContext|1|2|3|4|0|", context_key];
        [request setHTTPBody:[NSData dataWithBytes:[body UTF8String] length:strlen([body UTF8String])]];
        [request setHTTPMethod:@"POST"];
        
        [request setValue:@"text/x-gwt-rpc; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            step3(content_key, finances_key);
        }] resume];
    };
    
    // Start by getting the GWT-Permutation cache.html file with our RPC keys
    void (^step1)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"SIO: querying...");
        
        NSString *page = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:@"Ub='([^']+)'"
                                                  options:kNilOptions
                                                    error:&error];
        NSArray *matches = [regex matchesInString:page options:0 range:NSMakeRange(0, [page length])];
        
        if ([matches count] == 0) {
            if (handler != nil) {
                handler(NO);
            }
            return;
        }
        
        NSString *permutation = [page substringWithRange:[matches[0] rangeAtIndex:1]];
        
        NSMutableURLRequest *request = [self newRequest:[[NSString alloc] initWithFormat:@"https://s3.as.cmu.edu/sio/sio/%@.cache.html", permutation]];
        [[session dataTaskWithRequest:request completionHandler:step2] resume];
    };
    
    [CMUAuth authenticate:@"https://s3.as.cmu.edu/sio/index.html" onAuth:^(NSURLSession *s){
        if (s == nil) {
            if (handler != nil) {
                handler(NO);
            }
            return;
        }
        
        session = s;
        
        [[session dataTaskWithRequest:[self newRequest:@"https://s3.as.cmu.edu/sio/sio/sio.nocache.js"]
                    completionHandler:step1
          ] resume];
    }];
}

+ (void)getCourseInfo:(NSString*)course withHandler:(void (^)(NSDictionary*))handler {
    
    __block NSDictionary *courseData, *courseFCE;
    dispatch_group_t group = dispatch_group_create();
    
    // Get FCEs from WhichCourse (courtesy Yashas Kumar)
    NSMutableURLRequest *request = [self newRequest:@"http://whichcourse.herokuapp.com/"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"POST"];
    
    NSString *data = [[NSString alloc] initWithFormat:@"search=%@&json=true", course];
    [request setHTTPBody:[NSData dataWithBytes:[data UTF8String] length:strlen([data UTF8String])]];
    
    NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session =
    [NSURLSession sessionWithConfiguration:sessionConfig];
    
    dispatch_group_enter(group);
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        courseFCE = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        dispatch_group_leave(group);
    }] resume];
    
    // Get course info from ScottyLabs
    NSString *courseName = [course stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSString *url = [[NSString alloc] initWithFormat:@"https://apis.scottylabs.org/v1/schedule/S14/courses/%@?app_id=1b23c940-314c-4fbb-b7aa-fdf0e533569b&app_secret_key=Y5P9oO2flrJcbHsCaQrAwKQ8fSbwwXgAkQpkw0wCy85n1zwh6283i54i",
                     courseName];
    request = [self newRequest:url];
    
    dispatch_group_enter(group);
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        courseData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        dispatch_group_leave(group);
    }] resume];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSDictionary *data = @{@"course": courseData[@"course"] == nil ? [NSNull null] : courseData[@"course"],
                               @"fce": [courseFCE count] == 0 ? [NSNull null] : courseFCE[courseName]};
        if (handler != nil) {
            handler(data);
        }
    });
}

+ (void)finger:(NSString *)andrew withHandler:(void (^)(NSArray *))handler {
    
    NSString *url = [[NSString alloc] initWithFormat:@"http://willcrichton.net/finger.php?andrew=%@", andrew];
    NSMutableURLRequest *request = [self newRequest: url];
    
    NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session =
    [NSURLSession sessionWithConfiguration:sessionConfig];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *userInfo = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (handler != nil) {
            handler(userInfo);
        }
    }] resume];
}
@end