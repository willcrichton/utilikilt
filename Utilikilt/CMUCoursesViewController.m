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
#import "CMUUtil.h"

@interface CMUCoursesViewController ()
@property (weak, nonatomic) IBOutlet UITextField *courseField;
- (IBAction)onSearch:(id)sender;
@property (weak, nonatomic) IBOutlet UITableView *scheduleTable;
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
    self.scheduleTable.dataSource = (id)self;
    self.scheduleTable.delegate = (id)self;
    self.scheduleTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 1)] ;
    lineView.backgroundColor = [UIColor colorWithRed:224/255.0 green:224/255.0 blue:224/255.0 alpha:1.0];
    self.scheduleTable.tableHeaderView = lineView;
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
            
            if (![courseInfo isEqual:[NSNull null]] && ![courseInfo[@"course"] isEqual:[NSNull null]]) {
                self.courseInfo = courseInfo;
                [self performSegueWithIdentifier:@"CourseDetail" sender:self];
            } else {
                [[[UIAlertView alloc] initWithTitle:@"Course not found"
                                            message:@"Make sure the course number was entered correctly, such as 15-213 or 15213."
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


#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[CMUUtil load:@"sio_info"][@"schedule"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SchedulePrototype";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSDictionary *lecture = [CMUUtil load:@"sio_info"][@"schedule"][indexPath.item];
    NSArray *dayMap = @[@"M", @"Tu", @"W", @"Th", @"F"];
    
    UILabel *lecLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 300, 20)];
    [lecLabel setText:[CMUUtil truncate:lecture[@"name"] toLength:25]];
    
    UILabel *locLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, 300, 20)];
    [locLabel setText:lecture[@"location"]];
    
    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, cell.frame.size.width - 40, 20)];
    timeLabel.textAlignment = NSTextAlignmentRight;
   
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"hh:mma"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    
    NSString *time = [[NSString alloc] initWithFormat:@"%@ - %@",
                      [formatter stringFromDate:lecture[@"start_time"]], [formatter stringFromDate:lecture[@"end_time"]]];
    [timeLabel setText:time];
    
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(20   , 20, cell.frame.size.width - 40, 20)];
    nameLabel.textAlignment = NSTextAlignmentRight;
    
    NSMutableArray *days = [[NSMutableArray alloc] init];
    for (NSNumber *day in lecture[@"days"]) {
        [days addObject:dayMap[[day intValue] - 1]];
    }
    
    [nameLabel setText:[days componentsJoinedByString:@"/"]];
    
    [cell addSubview:lecLabel];
    [cell addSubview:timeLabel];
    [cell addSubview:locLabel];
    [cell addSubview:nameLabel];
    
    return cell;
}

@end
