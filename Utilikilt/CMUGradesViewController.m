//
//  CMUGradesViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import "CMUGradesViewController.h"
#import "CMUDrilldownViewController.h"
#import "CMUAuth.h"
#import "TFHpple.h"

@interface CMUGradesViewController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *category;
@property NSInteger selected;
@end

@implementation CMUGradesViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.category addTarget:self
                      action:@selector(showData)
            forControlEvents:UIControlEventValueChanged];
    
    self.selected = 0;
    [CMUAuth getCourseInfo:@"15-213" withHandler:nil];
}


- (void)viewWillAppear:(BOOL)animated {
    [self showData];
}

- (void)showData {
    [(UITableView*)[self view] reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSInteger idx = self.category.selectedSegmentIndex;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (idx == 0) {
        return [[defaults objectForKey:@"final_grades"] count];
    } else if (idx == 1) {
        return [[defaults objectForKey:@"blackboard_grades"] count];
    } else {
        return [[defaults objectForKey:@"autolab_grades"] count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"GradesPrototype";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger idx = self.category.selectedSegmentIndex;
    
    if (idx == 0) {
        NSArray *grades = [[defaults objectForKey:@"final_grades"] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
            return [obj1[0] caseInsensitiveCompare:obj2[0]];
        }];
        
        NSArray *entry = grades[indexPath.item];
        cell.textLabel.text = entry[0];
        cell.detailTextLabel.text = entry[1];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        NSDictionary *grades = [defaults objectForKey:(idx == 1 ? @"blackboard_grades" : @"autolab_grades")];
        NSArray *keys = [[grades allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        cell.textLabel.text = [keys objectAtIndex:indexPath.item];
        cell.detailTextLabel.text = @"";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger idx = self.category.selectedSegmentIndex;
    if (idx == 1 || idx == 2) {
        self.selected = indexPath.item;
        [self performSegueWithIdentifier:@"Drilldown" sender:self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger idx = self.category.selectedSegmentIndex;
    
    if (idx == 1 || idx == 2) {
        NSDictionary *grades = [defaults objectForKey:(idx == 1 ? @"blackboard_grades" : @"autolab_grades")];
        CMUDrilldownViewController *controller = [segue destinationViewController];
        
        NSDictionary *course = grades[[[grades allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)][self.selected]];
        NSArray *hws = [[course allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        
        NSMutableArray *drilldown = [[NSMutableArray alloc] init];
        for (NSString *hw in hws) {
            [drilldown addObject:@[hw, course[hw]]];
        }
        
        controller.grades = drilldown;
    }
    
}
@end
