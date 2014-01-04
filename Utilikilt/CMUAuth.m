//
//  CMUAuth.m
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import "CMUAuth.h"
#import "TFHpple.h"

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
        
        // todo: add Host field
        [request setValue:@"https://login.cmu.edu" forHTTPHeaderField:@"Origin"];
        [request setValue:@"https://login.cmu.edu/idp/profile/SAML2/Redirect/SSO" forHTTPHeaderField:@"Referer"];
        [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.14 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[NSData dataWithBytes:[data UTF8String] length:strlen([data UTF8String])]];
        
        [request setHTTPMethod:@"POST"];
        
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (handler != nil) {
                handler(session);
            }
        }] resume];
    };
    
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
    
    // LOL BLOCK VARIABLES WUT
    __block NSURLSession *session;
    
    void (^step2)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Final grades: step 2");
        
        // extract grades from academic audit page
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        NSMutableArray *grades = [[NSMutableArray alloc] init];
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//pre"]) {
            for (NSString* line in [[el text] componentsSeparatedByString:@"\n"]) {
                NSRegularExpression *regex =
                [NSRegularExpression regularExpressionWithPattern:@"(\\d+-\\d+) \\w+\\s*\\'\\d+ ((\\w|\\*)+)\\s*(\\d+\\.\\d)\\s*$"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&error];
                NSArray *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
                for (NSTextCheckingResult *match in matches) {
                    NSString *class = [line substringWithRange:[match rangeAtIndex:1]];
                    NSString *grade = [line substringWithRange:[match rangeAtIndex:2]];
                    [grades addObject:@[class, grade]];
                }
            }
        }
       
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *oldGrades = [defaults objectForKey:@"final_grades"];
        [defaults setObject:grades forKey:@"final_grades"];
        [defaults synchronize];
        
        // Show local notification for any changed grades
        for (NSArray *grade in grades) {
            for (NSArray *oldGrade in oldGrades){
                if (![[oldGrade objectAtIndex: 0] isEqualToString:[grade objectAtIndex:0]]) continue;
                if (![[oldGrade objectAtIndex: 1] isEqualToString:[grade objectAtIndex:1]]) {
                    UILocalNotification *note = [[UILocalNotification alloc] init];
                    note.fireDate = [NSDate date];
                    note.alertBody = [[NSString alloc] initWithFormat:@"New final grade for %@: %@",
                                      [grade objectAtIndex:0], [grade objectAtIndex:1]];
                    [[UIApplication sharedApplication] scheduleLocalNotification:note];
                }
            }
        }
        
        if (handler != nil) {
            handler(YES);
        }
    };
    
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
    
    NSMutableDictionary *grades = [[NSMutableDictionary alloc] init];
    NSLock *lock = [[NSLock alloc] init];
    
    void (^step2)() = ^(NSData *data, NSString *course) {
        [grades setObject:[[NSMutableDictionary alloc] init] forKey:course];
        
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        NSString *hw;
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//div"]) {
            NSString *class = [el objectForKey:@"class"];
            NSString *text = [[el text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([class isEqualToString:@"name"]) {
                hw = text;
            } else if ([class rangeOfString:@"gradeCellGrade"].location != NSNotFound) {
                NSString *grade = text;
                
                NSArray *children = [el childrenWithClassName:@"outof"];
                if ([children count] > 0) {
                    NSString *total = [[children[0] text] substringFromIndex:1];
                    [lock lock];
                    [grades[course] setObject:[[NSString alloc] initWithFormat:@"%@/%@", grade, total]
                                       forKey:hw];
                    [lock unlock];
                }
            }

        }
    };
    
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
        
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSLog(@"Blackboard grades: finished querying.");
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *oldGrades = [defaults objectForKey:@"blackboard_grades"];
            [defaults setObject:grades forKey:@"blackboard_grades"];
            [defaults synchronize];
            
            if ([oldGrades count] != 0) {
                for (NSString *course in grades) {
                    for (NSString *hw in grades[course]) {
                        if (oldGrades[course][hw] == nil) {
                            UILocalNotification *note = [[UILocalNotification alloc] init];
                            note.fireDate = [NSDate date];
                            note.alertBody = [[NSString alloc] initWithFormat:@"New final grade for %@ (%@): %@",
                                              hw, course, grades[course][hw]];
                            [[UIApplication sharedApplication] scheduleLocalNotification:note];
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
    
    NSMutableDictionary *grades = [[NSMutableDictionary alloc] init];
    NSLock *lock = [[NSLock alloc] init];
    
    void (^step2)() = ^(NSData *data, NSString *course) {
        [grades setObject:[[NSMutableDictionary alloc] init] forKey:course];
        
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        
        NSString *hw;
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//tr/td[1]//a | //tr/td[last()]"]) {
            if ([[el tagName] isEqualToString:@"a"]) {
                hw = [el text];
            } else {
                NSString *grade = [[NSString alloc] initWithFormat:@"%@/%@",
                                   [[[el childrenWithTagName:@"a"] firstObject] text],
                                   [[[el childrenWithTagName:@"span"] firstObject] text]];
                [lock lock];
                [grades[course] setObject:grade forKey:hw];
                [lock unlock];
            }
        }
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
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *oldGrades = [defaults objectForKey:@"autolab_grades"];
            [defaults setObject:grades forKey:@"autolab_grades"];
            [defaults synchronize];
            
            if ([oldGrades count] != 0) {
                for (NSString *course in grades) {
                    for (NSString *hw in grades[course]) {
                        if (oldGrades[course][hw] == nil) {
                            UILocalNotification *note = [[UILocalNotification alloc] init];
                            note.fireDate = [NSDate date];
                            note.alertBody = [[NSString alloc] initWithFormat:@"New final grade for %@ (%@): %@",
                                              hw, course, grades[course][hw]];
                            [[UIApplication sharedApplication] scheduleLocalNotification:note];
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
         
         dispatch_group_notify(group, dispatch_get_main_queue(), ^{
             if (handler != nil) {
                 handler(YES);
             }
         });
     }];
}

+ (void)getCourseInfo:(NSString*)course withHandler:(void (^)(NSDictionary*))handler {
    
    // Get FCEs
    NSMutableURLRequest *request = [self newRequest:@"http://whichcourse.herokuapp.com/"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"POST"];
    
    NSString *data = [[NSString alloc] initWithFormat:@"search=%@&json=true", course];
    [request setHTTPBody:[NSData dataWithBytes:[data UTF8String] length:strlen([data UTF8String])]];
    
    NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session =
    [NSURLSession sessionWithConfiguration:sessionConfig];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // json decode the data
    }] resume];
    
    // Get course info from ScottyLabs
    NSString *url = [[NSString alloc] initWithFormat:@"https://apis.scottylabs.org/v1/schedule/S14/courses/%@?app_id=1b23c940-314c-4fbb-b7aa-fdf0e533569b&app_secret_key=Y5P9oO2flrJcbHsCaQrAwKQ8fSbwwXgAkQpkw0wCy85n1zwh6283i54i",
                     [course stringByReplacingOccurrencesOfString:@"-" withString:@""]];
    request = [self newRequest:url];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *courseData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (handler != nil) {
            if (courseData != nil) {
                handler(courseData[@"course"]);
            } else {
                handler((NSDictionary*)[NSNull null]);
            }
        }
    }] resume];
}
@end