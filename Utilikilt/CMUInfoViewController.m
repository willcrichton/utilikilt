//
//  CMUInfoViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 1/7/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import "CMUInfoViewController.h"
#import "CMUFingerViewController.h"
#import "MBProgressHUD.h"
#import "CMUAuth.h"
#import "CMUUtil.h"

@interface CMUInfoViewController ()
@property (weak, nonatomic) IBOutlet UILabel *smcLabel;
@property (weak, nonatomic) IBOutlet UILabel *mailboxLabel;
@property (weak, nonatomic) IBOutlet UILabel *cardIDLabel;
@property (weak, nonatomic) IBOutlet UITextField *studentSearch;
@property NSArray *info;
@end

@implementation CMUInfoViewController

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
    self.studentSearch.delegate = (id)self;
}

- (void)viewWillAppear:(BOOL)animated {
    NSDictionary *sio_info = [CMUUtil load:@"sio_info"];
    self.smcLabel.text = sio_info[@"smc"];
    self.mailboxLabel.text = sio_info[@"mailbox"];
    self.cardIDLabel.text = sio_info[@"card_id"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (![sender isKindOfClass:[UIButton class]]) {
        CMUFingerViewController *controller = [segue destinationViewController];
        controller.info = self.info;
    }
}

- (IBAction)onSearch:(id)sender {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];

    [self.studentSearch resignFirstResponder];
    
    [CMUAuth finger:self.studentSearch.text withHandler:^(NSArray *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hide:YES];
            
            if (info == nil || [info count] == 0) {
                NSLog(@"%@", info);
                [[[UIAlertView alloc] initWithTitle:@"Student not found"
                                            message:@"Make sure the Andrew ID was entered correctly."
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil]
                 show];
                return;
            }
            
            self.info = info;
            [self performSegueWithIdentifier:@"Finger" sender:self];
        });         
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    [self onSearch:self];
    return YES;
}

@end
