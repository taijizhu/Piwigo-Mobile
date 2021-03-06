//
//  LoginViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LoginViewController.h"
#import "LoginViewController_iPhone.h"
#import "LoginViewController_iPad.h"
#import "SAMKeychain.h"
#import "Model.h"
#import "SessionService.h"
#import "ClearCache.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"

//#ifndef DEBUG_SESSION
//#define DEBUG_SESSION
//#endif

@interface LoginViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIAlertAction *httpLoginAction;

@end

@implementation LoginViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		
		self.piwigoLogo = [UIImageView new];
		self.piwigoLogo.translatesAutoresizingMaskIntoConstraints = NO;
		self.piwigoLogo.image = [UIImage imageNamed:@"piwigoLogo"];
		self.piwigoLogo.contentMode = UIViewContentModeScaleAspectFit;
		[self.view addSubview:self.piwigoLogo];
		
		self.serverTextField = [PiwigoTextField new];
		self.serverTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.serverTextField.placeholder = NSLocalizedString(@"login_serverPlaceholder", @"Server");
		self.serverTextField.text = [NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName];
		self.serverTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.serverTextField.autocorrectionType = UITextAutocorrectionTypeNo;
		self.serverTextField.keyboardType = UIKeyboardTypeURL;
		self.serverTextField.returnKeyType = UIReturnKeyNext;
		self.serverTextField.delegate = self;
		[self.view addSubview:self.serverTextField];
				
		self.userTextField = [PiwigoTextField new];
		self.userTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.userTextField.placeholder = NSLocalizedString(@"login_userPlaceholder", @"Username (optional)");
		self.userTextField.text = [Model sharedInstance].username;
		self.userTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		self.userTextField.autocorrectionType = UITextAutocorrectionTypeNo;
		self.userTextField.returnKeyType = UIReturnKeyNext;
		self.userTextField.delegate = self;
		[self.view addSubview:self.userTextField];
		
		self.passwordTextField = [PiwigoTextField new];
		self.passwordTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.passwordTextField.placeholder = NSLocalizedString(@"login_passwordPlaceholder", @"Password (optional)");
		self.passwordTextField.secureTextEntry = YES;
		self.passwordTextField.text = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:[Model sharedInstance].username];
		self.passwordTextField.returnKeyType = UIReturnKeyGo;
		self.passwordTextField.delegate = self;
		[self.view addSubview:self.passwordTextField];
		
		self.loginButton = [PiwigoButton new];
		self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
		[self.loginButton setTitle:NSLocalizedString(@"login", @"Login") forState:UIControlStateNormal];
		[self.loginButton addTarget:self action:@selector(launchLogin) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:self.loginButton];
		
		[self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)]];
		
		[self performSelector:@selector(setupAutoLayout) withObject:nil]; // now located in child VC, thus import .h files
	}
	return self;
}

-(void)launchLogin
{
    // User pressed "Login"
    [self.view endEditing:YES];

    // Default settings
    [Model sharedInstance].hasAdminRights = NO;
    [Model sharedInstance].usesCommunityPluginV29 = NO;
#if defined(DEBUG_SESSION)
    NSLog(@"=> launchLogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
#endif

    // Check server address and cancel login if address not provided
    if(self.serverTextField.text.length <= 0)
    {
        UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"loginEmptyServer_title", @"Enter a Web Address")
                message:NSLocalizedString(@"loginEmptyServer_message", @"Please select a protocol and enter a Piwigo web address in order to proceed.")
                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertOkButton", @"OK")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        
        return;
    }

    // Display HUD during login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connecting", @"Connecting")];
    });
    
    // Save server address and username to disk
    [self saveToDiskServerAddress:self.serverTextField.text andUsername:self.userTextField.text];
    
    // Save credentials in Keychain (needed before login when using HTTP Authentication)
    if(self.userTextField.text.length > 0)
    {
        // Store credentials in Keychain
        [SAMKeychain setPassword:self.passwordTextField.text forService:[Model sharedInstance].serverName account:self.userTextField.text];
    }

    // Collect list of methods supplied by Piwigo server
    // => Determine if Community extension 2.9a or later is installed and active
    [SessionService getMethodsListOnCompletion:^(NSDictionary *methodsList) {
        
        if(methodsList) {
            // Known methods, pursue logging in…
            [self performLogin];
        
        } else {
            // Methods unknown, so we cannot reach the server, inform user
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"serverMethodsError_message", @"Failed to get server methods.\nProblem with Piwigo server?"))];
        }
        
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        // If Piwigo server requires HTTP basic authentication, ask credentials
        if ([Model sharedInstance].performedHTTPauthentication){
            // Without prior knowledge, the app already tried Piwigo credentials
            // But unsuccessfully, so must now request HTTP credentials
            [self requestHttpCredentialsAfterError:[error localizedDescription]];
        } else {
            // Display error message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
        }
    }];
}

-(void)requestHttpCredentialsAfterError:(NSString *)error
{
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"loginHTTP_title", @"HTTP Credentials")
                                message:NSLocalizedString(@"loginHTTP_message", @"HTTP basic authentification is required by the Piwigo server:")
                                preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull userTextField) {
        userTextField.placeholder = NSLocalizedString(@"loginHTTPuser_placeholder", @"username");
        userTextField.clearButtonMode = UITextFieldViewModeAlways;
        userTextField.keyboardType = UIKeyboardTypeDefault;
        userTextField.returnKeyType = UIReturnKeyContinue;
        userTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        userTextField.delegate = self;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull pwdTextField) {
        pwdTextField.placeholder = NSLocalizedString(@"loginHTTPpwd_placeholder", @"password");
        pwdTextField.clearButtonMode = UITextFieldViewModeAlways;
        pwdTextField.keyboardType = UIKeyboardTypeDefault;
        pwdTextField.returnKeyType = UIReturnKeyContinue;
        pwdTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        pwdTextField.delegate = self;
    }];

    UIAlertAction* cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       // Stop logging in action, display error message
                                       [self loggingInConnectionError:error];
                                   }];
    
    self.httpLoginAction = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"alertOkButton", "OK")
                              style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * action) {
                                  // Store credentials
                                  [Model sharedInstance].HttpUsername = [alert.textFields objectAtIndex:0].text;
                                  [SAMKeychain setPassword:[alert.textFields objectAtIndex:1].text forService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:[alert.textFields objectAtIndex:0].text];
                                  // Try logging in with new HTTP credentials
                                  [self launchLogin];
                              }];
    
    [alert addAction:cancelAction];
    [alert addAction:self.httpLoginAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(void)performLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> performLogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
#endif
    
    // Perform Login if username exists
	if((self.userTextField.text.length > 0) && (![Model sharedInstance].userCancelledCommunication))
	{
        // Update HUD during login
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLoadingWithSubtitle:NSLocalizedString(@"login_newSession", @"Opening Session")];
        });
        
        // Perform login
        [SessionService performLoginWithUser:self.userTextField.text
								  andPassword:self.passwordTextField.text
								 onCompletion:^(BOOL result, id response) {
									 if(result)
									 {
                                         // Session now opened
                                         // First determine user rights if Community extension installed
                                         [self getCommunityStatusAtFirstLogin:YES];
                                      }
									 else
									 {
                                         // Don't keep credentials
                                         [SAMKeychain deletePasswordForService:[Model sharedInstance].serverName account:self.userTextField.text];

                                         // Session could not be re-opened
                                         [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"loginError_message", @"The username and password don't match on the given server"))];
									 }
								 } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                     // Display message
                                     [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
                                 }];
	}
	else     // No username, get only server status
	{
        // Reset keychain and credentials
        [SAMKeychain deletePasswordForService:[Model sharedInstance].serverName account:[Model sharedInstance].username];
        [Model sharedInstance].username = @"";
        [[Model sharedInstance] saveToDisk];

        // Check Piwigo version, get token, available sizes, etc.
        [self getCommunityStatusAtFirstLogin:YES];
    }
}

// Determine true user rights when Community extension installed
-(void)getCommunityStatusAtFirstLogin:(BOOL)isFirstLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> getCommunityStatusAtFirstLogin:%@ starting with…", isFirstLogin ? @"YES" : @"NO");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@,
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
#endif
    if(([Model sharedInstance].usesCommunityPluginV29) &&(![Model sharedInstance].userCancelledCommunication)) {

        // Update HUD during login
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLoadingWithSubtitle:NSLocalizedString(@"login_communityParameters", @"Community Parameters")];
        });
        
        // Community extension installed
        [SessionService getCommunityStatusOnCompletion:^(NSDictionary *responseObject) {
            
            if(responseObject)
            {
                // Check Piwigo version, get token, available sizes, etc.
                [self getSessionStatusAtLogin:YES andFirstLogin:isFirstLogin];
            
            } else {
                // Inform user that server failed to retrieve Community parameters
                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"serverCommunityError_message", @"Failed to get Community extension parameters.\nTry logging in again."))];
            }
            
        } onFailure:^(NSURLSessionTask *task, NSError *error) {
            // Display error message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
        }];

    } else {
        // Community extension not installed
        // Check Piwigo version, get token, available sizes, etc.
        [self getSessionStatusAtLogin:YES andFirstLogin:isFirstLogin];
    }
}

// Check Piwigo version, get token, available sizes, etc.
-(void)getSessionStatusAtLogin:(BOOL)isLoggingIn andFirstLogin:(BOOL)isFirstLogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> getSessionStatusAtLogin:%@ andFirstLogin:%@ starting with…",
          isLoggingIn ? @"YES" : @"NO", isFirstLogin ? @"YES" : @"NO");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
#endif
    if (![Model sharedInstance].userCancelledCommunication) {
        // Update HUD during login
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showLoadingWithSubtitle:NSLocalizedString(@"login_serverParameters", @"Piwigo Parameters")];
        });
        
        [SessionService getPiwigoStatusAtLogin:isLoggingIn
                                  OnCompletion:^(NSDictionary *responseObject) {
            if(responseObject)
            {
                if([@"2.7" compare:[Model sharedInstance].version options:NSNumericSearch] != NSOrderedAscending)
                {
                    // They need to update, ask user what to do
                    // Close loading or re-login view and ask what to do
                    [self hideLoadingWithCompletion:^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIAlertController* alert = [UIAlertController
                                    alertControllerWithTitle:NSLocalizedString(@"serverVersionNotCompatible_title", @"Server Incompatible")
                                    message:[NSString stringWithFormat:NSLocalizedString(@"serverVersionNotCompatible_message", @"Your server version is %@. Piwigo Mobile only supports a version of at least 2.7. Please update your server to use Piwigo Mobile\nDo you still want to continue?"), [Model sharedInstance].version]
                                    preferredStyle:UIAlertControllerStyleAlert];
                            
                            UIAlertAction* defaultAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction * action) {}];
                            
                            UIAlertAction* continueAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                    style:UIAlertActionStyleDestructive
                                    handler:^(UIAlertAction * action) {
                                        // Proceed at their own risk
                                        if (isFirstLogin) {
                                            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                            [appDelegate loadNavigation];
                                        }
                                    }];
                            
                            [alert addAction:defaultAction];
                            [alert addAction:continueAction];
                            [self presentViewController:alert animated:YES completion:nil];                            
                        });
                    }];
                } else {
                    // Their version is Ok. Close HUD.
                    [self hideLoadingWithCompletion:^{
                        // Load navigation if needed
                        if (isFirstLogin) {
                            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                            [appDelegate loadNavigation];
                        }
                    }];
                }
            } else {
                // Inform user that we could not authenticate with server
                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"sessionStatusError_message", @"Failed to authenticate with server.\nTry logging in again."))];
            }
        } onFailure:^(NSURLSessionTask *task, NSError *error) {
            // Display error message
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
        }];
    } else {
        [self loggingInConnectionError:nil];
    }
}

-(void)checkSessionStatusAndTryRelogin
{
    // Display HUD during re-login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connectionChanged", @"Connection Changed!")];
    });
    
    // Check whether session is still active
    [SessionService getPiwigoStatusAtLogin:NO
                                   OnCompletion:^(NSDictionary *responseObject) {
        if(responseObject) {
            
            // When the session is closed, user becomes guest
            NSString *userName = [responseObject objectForKey:@"username"];
#if defined(DEBUG_SESSION)
            NSLog(@"=> checkSessionStatusAndTryRelogin: username=%@", userName);
#endif
            if (![userName isEqualToString:[Model sharedInstance].username]) {

                // Session was closed, try relogging in assuming server did not change for speed
                [Model sharedInstance].hadOpenedSession = NO;
                [self performRelogin];

            } else {
                // Connection still alive. Close HUD and do nothing.
                [self hideLoading];
#if defined(DEBUG_SESSION)
                NSLog(@"=> checkSessionStatusAndTryRelogin: Connection still alive…");
                NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@",
                      ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
                      ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
#endif
            }
        } else {
            // Connection really lost, inform user
            [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"internetErrorGeneral_broken", @"Sorry, the communication was broken.\nTry logging in again."))];
        }
    } onFailure:^(NSURLSessionTask *task, NSError *error) {
        // No connection or server down
        [Model sharedInstance].hadOpenedSession = NO;
        
        // Display message
        [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
    }];
}

-(void)performRelogin
{
#if defined(DEBUG_SESSION)
    NSLog(@"=> performRelogin: starting with…");
    NSLog(@"   usesCommunityPluginV29=%@, hasAdminRights=%@",
          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
#endif
    
    // Update HUD during re-login
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showLoadingWithSubtitle:NSLocalizedString(@"login_connecting", @"Connecting")];
    });

    // Perform login
    NSString *user = [Model sharedInstance].username;
    NSString *password = [SAMKeychain passwordForService:[Model sharedInstance].serverName account:user];
    [SessionService performLoginWithUser:user
                             andPassword:password
                            onCompletion:^(BOOL result, id response) {
                                if(result)
                                {
                                    // Session now re-opened
                                    [Model sharedInstance].hadOpenedSession = YES;
                                    
                                    // First determine user rights if Community extension installed
                                    [self getCommunityStatusAtFirstLogin:NO];
                                }
                                else
                                {
                                    // Session could not be re-opened, inform user
                                    [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : NSLocalizedString(@"loginError_message", @"The username and password don't match on the given server"))];
                                }

                            } onFailure:^(NSURLSessionTask *task, NSError *error) {
                                // Could not re-establish the session, login/pwd changed, something else ?
                                [Model sharedInstance].hadOpenedSession = NO;
                                
                                // Display error message
                                [self loggingInConnectionError:([Model sharedInstance].userCancelledCommunication ? nil : [error localizedDescription])];
                            }];
}

#pragma mark -- HUD methods

-(void)showLoadingWithSubtitle:(NSString *)subtitle
{
    // Determine the present view controller if needed (not necessarily self.view)
    if (!self.hudViewController) {
        self.hudViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (self.hudViewController.presentedViewController) {
            self.hudViewController = self.hudViewController.presentedViewController;
        }
    }
    
    // Create the login HUD if needed
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (!hud) {        
        // Create the HUD
        hud = [MBProgressHUD showHUDAddedTo:self.hudViewController.view animated:YES];
        [hud setTag:loadingViewTag];

        // Change the background view shape, style and color.
        hud.square = NO;
        hud.animationType = MBProgressHUDAnimationFade;
        hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
        hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max) {
            hud.contentColor = [UIColor piwigoWhiteCream];
            hud.bezelView.color = [UIColor colorWithWhite:0.f alpha:1.0];
        } else {
            hud.contentColor = [UIColor piwigoGray];
            hud.bezelView.color = [UIColor piwigoGrayLight];
        }
        
        // Set title
        hud.label.text = NSLocalizedString(@"login_loggingIn", @"Logging In...");
        hud.label.font = [UIFont piwigoFontNormal];
    
        // Will look best, if we set a minimum size.
        hud.minSize = CGSizeMake(200.f, 100.f);

        // Configure the button.
        [hud.button setTitle:NSLocalizedString(@"internetCancelledConnection_button", @"Cancel Connection") forState:UIControlStateNormal];
        [hud.button addTarget:self action:@selector(cancelLoggingIn) forControlEvents:UIControlEventTouchUpInside];
    }
    
    // Update the subtitle
    hud.detailsLabel.text = subtitle;
    hud.detailsLabel.font = [UIFont piwigoFontSmall];
}

- (void)cancelLoggingIn
{
    // Propagate user's request
    [Model sharedInstance].userCancelledCommunication = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        // Update login HUD
        MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            // Update text
            hud.detailsLabel.text = NSLocalizedString(@"internetCancellingConnection_button", @"Cancelling Connection…");;
            
            // Reconfigure the button
            [hud.button isSelected];
            [hud.button removeTarget:self action:@selector(hideLoading) forControlEvents:UIControlEventTouchUpInside];
        }
    });
}

- (void)loggingInConnectionError:(NSString *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update login HUD
        MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
        if (hud) {
            // Show only text
            hud.mode = MBProgressHUDModeText;
            
            // Reconfigure the button
            [hud.button setTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss") forState:UIControlStateNormal];
            [hud.button addTarget:self action:@selector(hideLoading) forControlEvents:UIControlEventTouchUpInside];

            // Update text
            if (error == nil) {
                hud.label.text = NSLocalizedString(@"internetCancelledConnection_title", @"Connection Cancelled");
                hud.detailsLabel.text = @" ";
            } else {
                hud.label.text = NSLocalizedString(@"internetErrorGeneral_title", @"Connection Error");
                hud.detailsLabel.text = [NSString stringWithFormat:@"%@", error];
            }
        }
    });
}

-(void)hideLoading
{
    // Reinitialise flag
    [Model sharedInstance].userCancelledCommunication = NO;

    // Hide and remove login HUD
    MBProgressHUD *hud = [self.hudViewController.view viewWithTag:loadingViewTag];
    if (hud) {
        [hud hideAnimated:YES];
        self.hudViewController = nil;
    }
}

-(void)hideLoadingWithCompletion:(void (^ __nullable)(void))completion
{
    // Reinitialise flag
    [Model sharedInstance].userCancelledCommunication = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Hide and remove the HUD
        [self hideLoading];
        
        // Execute block
        if (completion) {
            completion();
        }
    });
}


#pragma mark -- UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable HTTP login action
    [self.httpLoginAction setEnabled:NO];
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable HTTP login action
    [self.httpLoginAction setEnabled:NO];
    return YES;
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Enable Add Category action if album name is non null
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [self.httpLoginAction setEnabled:(finalString.length >= 1)];
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if(textField == self.serverTextField) {
		[self.userTextField becomeFirstResponder];
	} else if (textField == self.userTextField) {
		[self.passwordTextField becomeFirstResponder];
	} else if (textField == self.passwordTextField) {
		if(self.view.frame.size.height > 320)
		{
			[self moveTextFieldsBy:self.topConstraintAmount];
		}
		[self launchLogin];
	}
	return YES;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
	if(self.view.frame.size.height > 500) return;
	
	NSInteger amount = 0;
	if (textField == self.userTextField)
	{
		amount = -self.topConstraintAmount;
	}
	else if (textField == self.passwordTextField)
	{
		amount = -self.topConstraintAmount * 2;
	}
	
	[self moveTextFieldsBy:amount];
}


#pragma mark -- Utilities

-(void)saveToDiskServerAddress:(NSString *)serverString andUsername:(NSString *)user
{
    [Model sharedInstance].username = user;
    
    // remove extrat "/" in server address
    if ([serverString hasSuffix:@"/"]) {
        serverString = [serverString substringWithRange:NSMakeRange(0, serverString.length-1)];
    }
    
    // Extract "http://" and set server proptocol
    NSRange httpRange = [serverString rangeOfString:@"http://" options:NSCaseInsensitiveSearch];
    if(httpRange.location == 0)
    {
        [Model sharedInstance].serverName = [serverString substringFromIndex:7];
        [Model sharedInstance].serverProtocol = @"http://";
    }
    
    // Extract "https://" and set server proptocol
    NSRange httpsRange = [serverString rangeOfString:@"https://" options:NSCaseInsensitiveSearch];
    if(httpsRange.location == 0)
    {
        [Model sharedInstance].serverName = [serverString substringFromIndex:8];
        [Model sharedInstance].serverProtocol = @"https://";
    }
    
    // Save username, server address and protocol to disk
    [[Model sharedInstance] saveToDisk];
}

-(void)moveTextFieldsBy:(NSInteger)amount
{
    self.logoTopConstraint.constant = amount;
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
}

-(void)dismissKeyboard
{
    [self moveTextFieldsBy:self.topConstraintAmount];
    [self.view endEditing:YES];
}

@end
