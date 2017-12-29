//
//  PreferencesViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/12/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#ifndef PreferencesViewController_h
#define PreferencesViewController_h

#endif /* PreferencesViewController_h */

#import <UIKit/UIKit.h>

@interface PreferencesViewController : UITableViewController

// Piwigo Server section
@property (weak, nonatomic) IBOutlet UILabel *serverNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *usernameLabel;

// General Settings section
@property (weak, nonatomic) IBOutlet UISwitch *loadAllCategoryInfoSwitch;
- (IBAction)loadAllCategoryInfoChanged:(id)sender;

@end
