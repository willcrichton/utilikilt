//
//  CMUSettingsViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 1/24/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import "CMUSettingsViewController.h"
#import "CMUUtil.h"

@interface CMUSettingsViewController ()
- (IBAction)onLogout:(id)sender;
@property (weak, nonatomic) IBOutlet UISwitch *gradeNotify;
@property (weak, nonatomic) IBOutlet UISwitch *rememberLogin;

@end

@implementation CMUSettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.gradeNotify addTarget:self
                         action:@selector(prefChange)
               forControlEvents:UIControlEventValueChanged];
    
    [self.rememberLogin addTarget:self
                           action:@selector(prefChange)
                 forControlEvents:UIControlEventValueChanged];
    
}

- (void)viewWillAppear:(BOOL)animated {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.gradeNotify.on = [[defaults objectForKey:@"grade_notifications"] boolValue];
    self.rememberLogin.on = [[defaults objectForKey:@"remember_login"] boolValue];
}

- (void)prefChange {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:self.gradeNotify.on] forKey:@"grade_notifications"];
    [defaults setObject:[NSNumber numberWithBool:self.rememberLogin.on] forKey:@"remember_login"];
    
    [defaults synchronize];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onLogout:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"" forKey:@"username"];
    [defaults setObject:@"" forKey:@"password"];
    [defaults synchronize];
    
    NSDictionary *dict = [[NSDictionary alloc] init];
    [CMUUtil save:dict toPath:@"final_grades"];
    [CMUUtil save:dict toPath:@"blackboard_grades"];
    [CMUUtil save:dict toPath:@"autolab_grades"];
        
    [self.tabBarController performSegueWithIdentifier:@"Settings" sender:self];
}
@end
