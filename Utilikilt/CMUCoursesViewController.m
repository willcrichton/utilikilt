//
//  CMUCoursesViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 1/1/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import "CMUCoursesViewController.h"
#import "CMUCourseDetailViewController.h"
#import "CMUAuth.h"
#import "MBProgressHUD.h"

@interface CMUCoursesViewController ()
@property (weak, nonatomic) IBOutlet UITextField *courseField;
- (IBAction)onSearch:(id)sender;
@property NSDictionary* courseInfo;
@end

@implementation CMUCoursesViewController

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
    self.courseField.delegate = (id)self;
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    [self doSearch];
    return YES;
}

- (void)doSearch {
    [self.courseField resignFirstResponder];

    NSString *course = [self.courseField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [CMUAuth getCourseInfo:course withHandler:^(NSDictionary *courseInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            
            if (![courseInfo isEqual:[NSNull null]]) {
                self.courseInfo = courseInfo;
                [self performSegueWithIdentifier:@"CourseDetail" sender:self];
            } else {
                [[[UIAlertView alloc] initWithTitle:@"Course not found"
                                            message:@"Make sure the course number was entered correctly."
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil]
                 show];
            }
        });
    }];
}   

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    [[segue destinationViewController] setCourse:self.courseInfo];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)onSearch:(id)sender {
    [self doSearch];
}
@end
