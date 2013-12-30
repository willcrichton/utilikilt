//
//  CMUSecondViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import "CMUSettingsViewController.h"
#import "MBProgressHUD.h"
#import "CMUAuth.h"
#import "CMUTabViewController.h"

@interface CMUSettingsViewController ()
@property (weak, nonatomic) IBOutlet UITextField *username;
@property (weak, nonatomic) IBOutlet UITextField *password;
- (IBAction)save:(id)sender;
@end

@implementation CMUSettingsViewController
- (void)viewDidLoad
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.password.text = [defaults objectForKey:@"password"];
    self.username.text = [defaults objectForKey:@"username"];
    
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)save:(id)sender {
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    // hide the keyboard
    [self.password resignFirstResponder];
    [self.username resignFirstResponder];
    
    NSString *username = [self.username text];
    NSString *password = [self.password text];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:username forKey:@"username"];
    [defaults setObject:password forKey:@"password"];
    [defaults synchronize];
    
    
    [CMUAuth loadAllGrades:^(BOOL didAuth) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hide:YES];
            if (didAuth) {
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Authentication failed"
                                                                message:@"Your username or password were incorrect. Please try again."
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
        });
    }];
}


@end
