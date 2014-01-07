//
//  CMUFCEViewController.m
//  Utilikilt
//
//  Created by Will Crichton on 1/4/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import "CMUFCEViewController.h"

@interface CMUFCEViewController ()
@property NSArray* evals;
@end

@implementation CMUFCEViewController

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

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setFCEs:(NSDictionary *)fce {
    if ([fce isEqual:[NSNull null]]) {
        self.evals = (NSArray*)[NSNull null];
        return;
    }
    
    NSMutableArray *evals = [[NSMutableArray alloc] init];
    
    for (NSString *teacher in fce) {
        [evals addObject:@[[[teacher capitalizedString] componentsSeparatedByString:@","][0], fce[teacher]]];
    }
    
    [evals sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj2[1][@"overall"] compare:obj1[1][@"overall"]];
    }];
    
    self.evals = [[NSArray alloc] initWithArray:evals];
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
    return [self.evals isEqual:[NSNull null]] ? 1 : [self.evals count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"FCEPrototype";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if ([self.evals isEqual:[NSNull null]]) {
        cell.textLabel.text = @"No FCEs were found for this course.";
        cell.detailTextLabel.text = @"";
    } else {
        NSArray *entry = self.evals[indexPath.item];
        cell.textLabel.text = [[NSString alloc] initWithFormat:@"%@: %@ hr/wk",
                               entry[0], entry[1][@"hours"]];
        cell.detailTextLabel.text = [[NSString alloc] initWithFormat:@"%@/100",
                                     entry[1][@"overall"]];
    }
    
    return cell;
}

@end
