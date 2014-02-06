//
//  CMUSecondViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import "CMULoginViewController.h"
#import "MBProgressHUD.h"
#import "CMUAuth.h"
#import "CMUTabViewController.h"

@interface CMULoginViewController ()
@property (weak, nonatomic) IBOutlet UITextField *username;
@property (weak, nonatomic) IBOutlet UITextField *password;
- (IBAction)save:(id)sender;
@end

@implementation CMULoginViewController
- (void)viewDidLoad
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.password.text = [defaults objectForKey:@"password"];
    self.username.text = [defaults objectForKey:@"username"];
    
    self.username.delegate = (id)self;
    self.password.delegate = (id)self;
        
    [super viewDidLoad];
}


- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    if ([textField isEqual:self.username]) {
        [self.password becomeFirstResponder];
    } else {
        [self save:self];
    }
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)save:(id)sender {
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Loading your data...";
    hud.detailsLabelText = @"This may take a minute. If some grades don't load (blame CMU), hit the refresh button that will show in the top right.";
    
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
