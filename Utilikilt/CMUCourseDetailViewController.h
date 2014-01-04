//
//  CMUCourseDetailViewController.h
//  Utilikilt
//
//  Created by Will Crichton on 1/1/14.
//  Copyright (c) 2014 Will Crichton. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CMUCourseDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
- (void)setCourse:(NSDictionary*)course;
@end
