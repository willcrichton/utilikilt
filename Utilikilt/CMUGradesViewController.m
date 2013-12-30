//
//  CMUGradesViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 12/17/13.
//  Copyright (c) 2013 Will Crichton. All rights reserved.
//

#import "CMUGradesViewController.h"
#import "CMUAuth.h"
#import "TFHpple.h"

@interface CMUGradesViewController ()
@property NSArray* grades;
@property (weak, nonatomic) IBOutlet UISegmentedControl *category;
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
    
    
}


- (void)viewWillAppear:(BOOL)animated {
    [self showData];
}

- (void)showData {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger idx = self.category.selectedSegmentIndex;
    
    if (idx == 0) {
        self.grades = [defaults objectForKey:@"final_grades"];
    } else if (idx == 1) {
        //self.grades = [defaults objectForKey:@"final_grades"];
        self.grades = [[NSArray alloc] init];
    } else {
        self.grades = [[NSArray alloc] init];
        //self.grades = [defaults objectForKey:@"final_grades"];
    }
    
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
    return [self.grades count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"GradesPrototype";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    cell.textLabel.text = [[self.grades objectAtIndex:indexPath.item] objectAtIndex:0];
    cell.detailTextLabel.text = [[self.grades objectAtIndex:indexPath.item] objectAtIndex:1];
    
    return cell;
}
@end
