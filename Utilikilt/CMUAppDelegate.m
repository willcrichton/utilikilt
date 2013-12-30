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
    //[NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(loadGrades) userInfo:nil repeats:YES];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"username"] == nil) {
        [self performSelector:@selector(showSettings) withObject:nil afterDelay:0.1];
    }
    
    /*
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:root.view animated:YES];
    hud.labelText = @"Authenticating...";
    
    [CMUAuth authenticate:@"https://s3.as.cmu.edu/sio/index.html" onAuth:^(NSURLSession *session) {
        [hud hide:YES];
        if (session == nil) {
            [root performSegueWithIdentifier:@"Settings" sender:self];
        }
    }];*/
    
    return YES;
}

- (void)showSettings {
    UIViewController *root = [[[[UIApplication sharedApplication] windows] lastObject] rootViewController];
    [root performSegueWithIdentifier:@"Settings" sender:self];
}

- (void)loadGrades {
    [CMUAuth loadFinalGrades:^(BOOL success) {
        if (!success) {
            NSLog(@"FAIL WHALE");
        }
    }];
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
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
