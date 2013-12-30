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
        
        TFHppleElement *el = [[doc searchWithXPathQuery:@"//form"] objectAtIndex: 0];
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
            if (handler != nil) {
                handler(session);
            }
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
@end