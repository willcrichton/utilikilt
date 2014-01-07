//
//  CMUCourseDetailViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 1/1/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import "CMUCourseDetailViewController.h"
#import "CMUFCEViewController.h"

@interface CMUCourseDetailViewController ()
@property (weak, nonatomic) IBOutlet UILabel *ctitle;
@property (weak, nonatomic) IBOutlet UILabel *unitsLabel;
@property (weak, nonatomic) IBOutlet UITableView *sectionTable;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *fceButton;
@property NSDictionary* courseInfo;
@end

@implementation CMUCourseDetailViewController

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
    self.sectionTable.dataSource = (id)self;
    self.sectionTable.delegate = (id)self;
    self.sectionTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 1)] ;
    lineView.backgroundColor = [UIColor colorWithRed:224/255.0 green:224/255.0 blue:224/255.0 alpha:1.0];
    self.sectionTable.tableHeaderView = lineView;
}

- (void)viewWillAppear:(BOOL)animated {
    self.navigationItem.title = self.courseInfo[@"course"][@"number"];
    self.ctitle.text = self.courseInfo[@"course"][@"name"];
    self.unitsLabel.text = [[NSString alloc] initWithFormat:@"%@ units",
                            self.courseInfo[@"course"][@"units"]];
}

- (void)setCourse:(NSDictionary*)course {
    self.courseInfo = course;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (sender == (id)self.fceButton) {
        [[segue destinationViewController] setFCEs:self.courseInfo[@"fce"]];
    }
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.courseInfo[@"course"][@"lectures"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CoursePrototype";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    NSDictionary *lecture = self.courseInfo[@"course"][@"lectures"][indexPath.item];
    
    UILabel *lecLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, 300, 20)];
    [lecLabel setText:[[NSString alloc] initWithFormat:@"%@ (%@)", lecture[@"section"], lecture[@"days"]]];
    
    UILabel *locLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, 300, 20)];
    [locLabel setText:lecture[@"location"]];
    
    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, cell.frame.size.width - 40, 20)];
    timeLabel.textAlignment = NSTextAlignmentRight;
    NSString *time = [[NSString alloc] initWithFormat:@"%@ - %@",
                      lecture[@"time_start"], lecture[@"time_end"]];
    [timeLabel setText:time];
    
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, cell.frame.size.width - 40, 20)];
    nameLabel.textAlignment = NSTextAlignmentRight;
    [nameLabel setText:lecture[@"instructors"]];
    
    [cell addSubview:lecLabel];
    [cell addSubview:timeLabel];
    [cell addSubview:locLabel];
    [cell addSubview:nameLabel];
    
    return cell;
}

@end
