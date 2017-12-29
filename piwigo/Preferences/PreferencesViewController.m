//
//  PreferencesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/12/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import "PreferencesViewController.h"
#import "AlbumService.h"
#import "AppDelegate.h"
#import "ClearCache.h"
#import "Model.h"
#import "SessionService.h"

typedef enum {
    SettingsSectionServer,
    SettingsSectionLogout,
    SettingsSectionGeneral,
    SettingsSectionImageUpload,
    SettingsSectionCache,
    SettingsSectionAbout,
    SettingsSectionCount
} SettingsSection;

@interface PreferencesViewController () <UITableViewDataSource, UITableViewDelegate>

@end

@implementation PreferencesViewController

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
    // Do any additional setup after loading the view.
    
    // Piwigo Server section
    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
    if (self.view.bounds.size.width > 414) {     // i.e. larger than iPhones 6, 7 screen width
        self.serverNameLabel.text = [NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
    } else {
        self.serverNameLabel.text = [Model sharedInstance].serverName;
    }
    if ([Model sharedInstance].username.length > 0) {
        self.usernameLabel.text = [Model sharedInstance].username;
    } else {
        self.usernameLabel.text = NSLocalizedString(@"settings_notLoggedIn", @" - Not Logged In - ");
    }
    
    // General Settings section
    self.loadAllCategoryInfoSwitch.selected = [Model sharedInstance].loadAllCategoryInfo;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -- UITableView headers

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, (section == 1 ? 0.0 : 36.0 ))];
    header.backgroundColor = [UIColor clearColor];
    
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoWhiteCream];
    [header addSubview:headerLabel];
    
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    
    switch(section)
    {
        case SettingsSectionServer:
            headerLabel.text = NSLocalizedString(@"settingsHeader_server", @"Piwigo Server");
            break;
        case SettingsSectionGeneral:
            headerLabel.text = NSLocalizedString(@"settingsHeader_general", @"General Settings");
            break;
        case SettingsSectionImageUpload:
            headerLabel.text = NSLocalizedString(@"settingsHeader_upload", @"Default Upload Settings");
            break;
        case SettingsSectionCache:
            headerLabel.text = NSLocalizedString(@"settingsHeader_cache", @"Cache Settings (Used/Total)");
            break;
        case SettingsSectionAbout:
            headerLabel.text = NSLocalizedString(@"settingsHeader_about", @"Information");
            break;
    }
    
    return header;
}


#pragma mark -- UITableView actions

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch(indexPath.section)
    {
        case SettingsSectionServer:      // Piwigo Server
            break;
        case SettingsSectionLogout:      // Logout
            [self logout];
            break;
        case SettingsSectionAbout:       // About — Informations
        {
            switch(indexPath.row)
            {
                case 0:     // Open Piwigo support forum webpage with default browser
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:NSLocalizedString(@"settings_pwgForumURL", @"http://piwigo.org/forum")]];
                    break;
                }
                case 1:     // Open Piwigo App Store page for rating
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://itunes.apple.com/app/piwigo/id%lu?action=write-review"]];
                    break;
                }
                case 2:     // Open Piwigo Crowdin page for translating
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://crowdin.com/project/piwigo-mobile"]];
                    break;
                }
            }
        }
    }
}


#pragma mark -- Other actions

-(void)logout
{
    if([Model sharedInstance].username.length > 0)
    {
        // Ask user for confirmation
        UIAlertController* alert = [UIAlertController
                                    alertControllerWithTitle:NSLocalizedString(@"logoutConfirmation_title", @"Logout")
                                    message:NSLocalizedString(@"logoutConfirmation_message", @"Are you sure you want to logout?")
                                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* cancelAction = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {}];
        
        UIAlertAction* logoutAction = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                       style:UIAlertActionStyleDestructive
                                       handler:^(UIAlertAction * action) {
                                           [SessionService sessionLogoutOnCompletion:^(NSURLSessionTask *task, BOOL sucessfulLogout) {
                                               if(sucessfulLogout)
                                               {
                                                   // Session closed
                                                   [Model sharedInstance].hadOpenedSession = NO;
                                                   
                                                   // Back to default values
                                                   [Model sharedInstance].usesCommunityPluginV29 = NO;
                                                   [Model sharedInstance].hasAdminRights = NO;
                                                   
                                                   // Erase cache
                                                   [ClearCache clearAllCache];
                                                   AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                                   [appDelegate loadLoginView];
                                               }
                                               else
                                               {
                                                   // Failed, retry ?
                                                   UIAlertController* alert = [UIAlertController
                                                                               alertControllerWithTitle:NSLocalizedString(@"logoutFail_title", @"Logout Failed")
                                                                               message:NSLocalizedString(@"logoutFail_message", @"Failed to logout\nTry again?")
                                                                               preferredStyle:UIAlertControllerStyleAlert];
                                                   
                                                   UIAlertAction* dismissAction = [UIAlertAction
                                                                                   actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                                                                   style:UIAlertActionStyleCancel
                                                                                   handler:^(UIAlertAction * action) {}];
                                                   
                                                   UIAlertAction* retryAction = [UIAlertAction
                                                                                 actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                                                                 style:UIAlertActionStyleDestructive
                                                                                 handler:^(UIAlertAction * action) {
                                                                                     [self logout];
                                                                                 }];
                                                   
                                                   [alert addAction:dismissAction];
                                                   [alert addAction:retryAction];
                                                   [self presentViewController:alert animated:YES completion:nil];
                                               }
                                           } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                               // Error message already presented
                                           }];
                                       }];
        
        [alert addAction:cancelAction];
        [alert addAction:logoutAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    else
    {
        [ClearCache clearAllCache];
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate loadLoginView];
    }
}

// User changed "load all category info" option
- (IBAction)loadAllCategoryInfoChanged:(id)sender {
    
    if(![Model sharedInstance].loadAllCategoryInfo && self.loadAllCategoryInfoSwitch.on)
    {
        [AlbumService getAlbumListForCategory:-1 OnCompletion:nil onFailure:nil];
    }

    [Model sharedInstance].loadAllCategoryInfo = self.loadAllCategoryInfoSwitch.on;
    [[Model sharedInstance] saveToDisk];
}


@end
