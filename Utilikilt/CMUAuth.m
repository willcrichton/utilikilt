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
+ (void)step1:(void (^)(NSURLSession*))handler withSession:(NSURLSession*)session;
+ (void)step2:(NSData*)page onAuth:(void (^)(NSURLSession*))handler withSession:(NSURLSession*)session;
@end

@implementation CMUAuth
+ (void) authenticate:(NSString*)url onAuth:(void (^)(NSURLSession*))handler {
    // create the main session for sending requests
    NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session =
    [NSURLSession sessionWithConfiguration:sessionConfig
                                  delegate:(id)self
                             delegateQueue:[NSOperationQueue mainQueue]];
    
    [[session dataTaskWithURL:[NSURL URLWithString:url]
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                [self step1:handler withSession:session];
            }] resume];
}

+ (void)step1:(void (^)(NSURLSession*))handler withSession:(NSURLSession*)session{
    NSURL *url = [NSURL URLWithString:@"https://login.cmu.edu/idp/Authn/Stateless"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:60.0];
    
    [request setValue:@"login.cmu.edu" forHTTPHeaderField:@"Host"];
    [request setValue:@"https://login.cmu.edu/idp/Authn/Stateless" forHTTPHeaderField:@"Referer"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:@"POST"];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *data = [[NSString alloc] initWithFormat:@"j_username=%@&j_password=%@&j_continue=1&submit=Login",
                      [defaults objectForKey:@"username"], [defaults objectForKey:@"password"]];
    [request setHTTPBody:[NSData dataWithBytes:[data UTF8String] length:strlen([data UTF8String])]];
    
    [[session dataTaskWithRequest:request
                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                         [self step2:data onAuth:handler withSession:session];
                     }] resume];
}

+ (void)step2:(NSData*)page onAuth:(void (^)(NSURLSession*))handler withSession:(NSURLSession*)session {
    TFHpple *doc = [[TFHpple alloc] initWithHTMLData:page];
    TFHppleElement *el = [[doc searchWithXPathQuery:@"//form"] objectAtIndex: 0];
    NSString* action = [el objectForKey:@"action"];

    NSString *data = @"a=b";
    NSArray *inputs = [doc searchWithXPathQuery:@"//input"];
    for (TFHppleElement *input in inputs) {
        NSString *name = [input objectForKey:@"name"];
        if ([name isEqualToString:@"submit"] || name.length == 0) continue;
        
        data = [NSString stringWithFormat:@"%@&%@=%@", data, name, [input objectForKey:@"value"]];
    }
    
    NSURL *url = [NSURL URLWithString:action];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                        timeoutInterval:60.0];

    data = [data stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    
    // todo: add Host field
    [request setValue:@"https://login.cmu.edu" forHTTPHeaderField:@"Origin"];
    [request setValue:@"https://login.cmu.edu/idp/profile/SAML2/Redirect/SSO" forHTTPHeaderField:@"Referer"];
    [request setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.14 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSData dataWithBytes:[data UTF8String] length:strlen([data UTF8String])]];

    [request setHTTPMethod:@"POST"];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        handler(session);
    }] resume];
}
@end