//
//  CMUInfoViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 1/7/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import "CMUInfoViewController.h"

@interface CMUInfoViewController ()
@property (weak, nonatomic) IBOutlet UILabel *smcLabel;
@property (weak, nonatomic) IBOutlet UILabel *mailboxLabel;

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
	// Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *sio_info = [defaults objectForKey:@"sio_info"];
    self.smcLabel.text = sio_info[@"smc"];
    self.mailboxLabel.text = sio_info[@"mailbox"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
