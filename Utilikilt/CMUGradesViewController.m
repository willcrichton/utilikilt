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
#import "MBProgressHUD.h"
#import "CMUUtil.h"

@interface CMUGradesViewController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *category;
- (IBAction)onRefresh:(id)sender;
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
        NSArray *grades = [defaults objectForKey:@"final_grades"];
        NSDictionary *entry = grades[indexPath.item];
        cell.textLabel.text = entry[@"course"];
        cell.detailTextLabel.text = entry[@"grade"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        NSArray *grades = [defaults objectForKey:(idx == 1 ? @"blackboard_grades" : @"autolab_grades")];
        cell.textLabel.text = [CMUUtil truncate:[grades objectAtIndex:indexPath.item][@"course"]
                                       toLength:40];
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
        NSArray *grades = [defaults objectForKey:(idx == 1 ? @"blackboard_grades" : @"autolab_grades")];
        CMUDrilldownViewController *controller = [segue destinationViewController];
        controller.grades = grades[self.selected][@"hws"];
        controller.navigationItem.title = grades[self.selected][@"course"];
    }
    
}
- (IBAction)onRefresh:(id)sender {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = @"Refreshing grades...";
    
    void (^callback)(BOOL) = ^(BOOL worked){
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        [self viewWillAppear:YES];
        
        if (!worked) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fetching grades failed"
                                                            message:@"The server failed to provide your grades. Try again in a few minutes."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];

        }
    };
    
    NSInteger idx = self.category.selectedSegmentIndex;
    if (idx == 0) {
        [CMUAuth loadFinalGrades:callback];
    } else if (idx == 1) {
        [CMUAuth loadBlackboardGrades:callback];
    } else {
        [CMUAuth loadAutolabGrades:callback];
    }
}
@end
