//
//  CMUSecondViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import "CMUSecondViewController.h"

@interface CMUSecondViewController ()
@property (weak, nonatomic) IBOutlet UITextField *username;
@property (weak, nonatomic) IBOutlet UITextField *password;
- (IBAction)save:(id)sender;
@end

@implementation CMUSecondViewController
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
    
    NSLog(@"HELLO?");
    
    // hide the keyboard
    [self.password resignFirstResponder];
    [self.username resignFirstResponder];
    
    NSString *username = [self.username text];
    NSString *password = [self.password text];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:username forKey:@"username"];
    [defaults setObject:password forKey:@"password"];
    [defaults synchronize];
}


@end
