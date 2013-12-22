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
- (NSMutableURLRequest*)newRequest:(NSString*)url;
- (void)loadBlackboardGrades:(NSURLSession*)session;
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

- (NSMutableURLRequest*)newRequest:(NSString *)url {
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:60.0];
}

- (void)loadBlackboardGrades:(NSURLSession*)session {
    NSMutableURLRequest *request = [self newRequest:@"https://enr-apps.as.cmu.edu/audit/audit?call=2"];
    
    void (^step2)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Step 2");
        
        // extract grades from academic audit page
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        NSMutableArray *grades = [[NSMutableArray alloc] init];
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//pre"]) {
            for (NSString* line in [[el text] componentsSeparatedByString:@"\n"]) {
                NSRegularExpression *regex =
                    [NSRegularExpression regularExpressionWithPattern:@"(\\d+-\\d+) \\w+\\s*\\'\\d+ ((\\w|\\*)+)\\s*(\\d+\\.\\d)\\s*$"
                                                              options:NSRegularExpressionCaseInsensitive
                                                                error:&error];
                NSArray *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
                for (NSTextCheckingResult *match in matches) {
                    NSString *class = [line substringWithRange:[match rangeAtIndex:1]];
                    NSString *grade = [line substringWithRange:[match rangeAtIndex:2]];
                    [grades addObject:@[class, grade]];
                }
            }
        }
        
        //[grades replaceObjectAtIndex:0 withObject:@[@"15-122", @"A"]];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *oldGrades = [defaults objectForKey:@"final_grades"];
        [defaults setObject:grades forKey:@"final_grades"];
        [defaults synchronize];
        
        // Show local notification for any changed grades
        for (NSArray *grade in grades) {
            for (NSArray *oldGrade in oldGrades){
                if (![[oldGrade objectAtIndex: 0] isEqualToString:[grade objectAtIndex:0]]) continue;
                if (![[oldGrade objectAtIndex: 1] isEqualToString:[grade objectAtIndex:1]]) {
                    UILocalNotification *note = [[UILocalNotification alloc] init];
                    note.fireDate = [NSDate date];
                    note.alertBody = [[NSString alloc] initWithFormat:@"New final grade for %@: %@",
                                      [grade objectAtIndex:0], [grade objectAtIndex:1]];
                    [[UIApplication sharedApplication] scheduleLocalNotification:note];
                }
            }
        }
    };
    
    void (^step1)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSLog(@"Step 1");
        
        //
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        NSString *newUrl = @"https://enr-apps.as.cmu.edu/audit/audit?call=7";
        for (TFHppleElement* el in [doc searchWithXPathQuery:@"//input"]) {
            if (![[el objectForKey:@"type"] isEqualToString:@"hidden"] ||
                [[el objectForKey:@"name"] isEqualToString:@"call"]) continue;
            newUrl = [newUrl stringByAppendingFormat:@"&%@=%@", [el objectForKey:@"name"], [el objectForKey:@"value"]];
        }
        
        newUrl = [newUrl stringByReplacingOccurrencesOfString:@" " withString:@"+"];
        [[session dataTaskWithRequest:[self newRequest:newUrl] completionHandler:step2] resume];
    };
    
    [[session dataTaskWithRequest:request
                completionHandler:step1
      ] resume];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    void (^onAuth)() = ^(NSURLSession* session) {
        [self loadBlackboardGrades:session];
    };
   
    [CMUAuth authenticate:@"https://enr-apps.as.cmu.edu/audit/audit" onAuth:onAuth];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.grades = [defaults objectForKey:@"final_grades"];
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
