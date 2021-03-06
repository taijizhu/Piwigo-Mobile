//
//  LoginViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoButton.h"
#import "PiwigoTextField.h"

@interface LoginViewController : UIViewController

@property (nonatomic, strong) UIImageView *piwigoLogo;
@property (nonatomic, strong) PiwigoTextField *serverTextField;
@property (nonatomic, strong) PiwigoTextField *userTextField;
@property (nonatomic, strong) PiwigoTextField *passwordTextField;
@property (nonatomic, strong) PiwigoButton *loginButton;

@property (nonatomic, strong) NSLayoutConstraint *logoTopConstraint;
@property (nonatomic, assign) NSInteger topConstraintAmount;
@property (nonatomic, strong) UIViewController *hudViewController;

-(void)launchLogin;
-(void)checkSessionStatusAndTryRelogin;

@end
