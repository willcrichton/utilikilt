//
//  CMUAppDelegate.m
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import "CMUAppDelegate.h"
#import "CMUAuth.h"
#import "MBProgressHUD.h"

@implementation CMUAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    [application setMinimumBackgroundFetchInterval:60.0];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"remember_login"] == nil) {
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:@"remember_login"];
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:@"grade_notifications"];
        [defaults synchronize];
    }
    
    return YES;
}

- (void)showSettings {
    UIViewController *root = [[[[UIApplication sharedApplication] windows] lastObject] rootViewController];
    [root performSegueWithIdentifier:@"Settings" sender:self];
}

- (void)application:(UIApplication*)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if([[defaults objectForKey:@"remember_login"] isEqualToNumber:[NSNumber numberWithBool:NO]]) {
        completionHandler(UIBackgroundFetchResultNoData);
    } else {
        [CMUAuth loadAllGrades:^(BOOL b) {
            completionHandler(b ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultFailed);
        }];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if([[defaults objectForKey:@"remember_login"] isEqualToNumber:[NSNumber numberWithBool:NO]]) {
        [defaults setObject:@"" forKey:@"username"];
        [defaults setObject:@"" forKey:@"password"];
        [defaults synchronize];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"username"] == nil || [[defaults objectForKey:@"username"] isEqualToString:@""]) {
        [self performSelector:@selector(showSettings) withObject:nil afterDelay:0.1];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
 
}

@end
