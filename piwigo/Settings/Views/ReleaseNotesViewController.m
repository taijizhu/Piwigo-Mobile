//
//  ReleaseNotesViewController.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//

#import <sys/utsname.h>                    // For determining iOS device model
#import "ReleaseNotesViewController.h"

@interface ReleaseNotesViewController ()

@property (nonatomic, strong) UILabel *piwigoTitle;
@property (nonatomic, strong) UILabel *byLabel1;
@property (nonatomic, strong) UILabel *byLabel2;
@property (nonatomic, strong) UILabel *versionLabel;
@property (nonatomic, strong) UILabel *releaseNotes;

@property (nonatomic, strong) UITextView *textView;

@end

@implementation ReleaseNotesViewController

-(instancetype)init
{
    self = [super init];
    if(self)
    {
        self.view.backgroundColor = [UIColor piwigoGray];
        self.title = NSLocalizedString(@"settings_releaseNotes", @"Release Notes");
        
        self.piwigoTitle = [UILabel new];
        self.piwigoTitle.translatesAutoresizingMaskIntoConstraints = NO;
        self.piwigoTitle.font = [UIFont piwigoFontNormal];
        self.piwigoTitle.font = [self.piwigoTitle.font fontWithSize:30];
        self.piwigoTitle.textColor = [UIColor piwigoOrange];
        self.piwigoTitle.text = NSLocalizedString(@"settings_appName", @"Piwigo Mobile");
        [self.view addSubview:self.piwigoTitle];
        
        self.byLabel1 = [UILabel new];
        self.byLabel1.translatesAutoresizingMaskIntoConstraints = NO;
        self.byLabel1.font = [UIFont piwigoFontNormal];
        self.byLabel1.font = [self.byLabel1.font fontWithSize:16];
        self.byLabel1.textColor = [UIColor piwigoWhiteCream];
        self.byLabel1.text = NSLocalizedStringFromTableInBundle(@"authors1", @"About", [NSBundle mainBundle], @"By Spencer Baker, Olaf Greck,");
        [self.view addSubview:self.byLabel1];
        
        self.byLabel2 = [UILabel new];
        self.byLabel2.translatesAutoresizingMaskIntoConstraints = NO;
        self.byLabel2.font = [UIFont piwigoFontNormal];
        self.byLabel2.font = [self.byLabel2.font fontWithSize:16];
        self.byLabel2.textColor = [UIColor piwigoWhiteCream];
        self.byLabel2.text = NSLocalizedStringFromTableInBundle(@"authors2", @"About", [NSBundle mainBundle], @"and Eddy Lelièvre-Berna");
        [self.view addSubview:self.byLabel2];
        
        self.versionLabel = [UILabel new];
        self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.versionLabel.font = [UIFont piwigoFontNormal];
        self.versionLabel.font = [self.versionLabel.font fontWithSize:10];
        self.versionLabel.textColor = [UIColor piwigoWhiteCream];
        [self.view addSubview:self.versionLabel];
        
        NSString * appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString * appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
        self.versionLabel.text = [NSString stringWithFormat:@"— %@ %@ (%@) —", NSLocalizedString(@"Version:", nil), appVersionString, appBuildString];
        
        self.textView = [UITextView new];
        self.textView.restorationIdentifier = @"release+notes";
        self.textView.translatesAutoresizingMaskIntoConstraints = NO;
        self.textView.layer.cornerRadius = 5;
        [self.view addSubview:self.textView];
        
        // Release notes attributed string
        NSMutableAttributedString *notesAttributedString = [[NSMutableAttributedString alloc] initWithString:@"\n\n\n\n\n"];
                
        // Release 2.1.6 — Bundle string
        NSString *v216String = NSLocalizedStringFromTableInBundle(@"v2.1.6_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.6 Release Notes text");
        NSRange v216Range = NSMakeRange(0, [v216String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v216AttributedString = [[NSMutableAttributedString alloc] initWithString:v216String];
        [v216AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v216Range];
        [notesAttributedString appendAttributedString:v216AttributedString];

        // Release 2.1.5 — Bundle string
        NSString *v215String = NSLocalizedStringFromTableInBundle(@"v2.1.5_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.5 Release Notes text");
        NSRange v215Range = NSMakeRange(0, [v215String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v215AttributedString = [[NSMutableAttributedString alloc] initWithString:v215String];
        [v215AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v215Range];
        [notesAttributedString appendAttributedString:v215AttributedString];

        // Release 2.1.4 — Bundle string
        NSString *v214String = NSLocalizedStringFromTableInBundle(@"v2.1.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.4 Release Notes text");
        NSRange v214Range = NSMakeRange(0, [v214String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v214AttributedString = [[NSMutableAttributedString alloc] initWithString:v214String];
        [v214AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v214Range];
        [notesAttributedString appendAttributedString:v214AttributedString];

        // Release 2.1.3 — Bundle string
        NSString *v213String = NSLocalizedStringFromTableInBundle(@"v2.1.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.3 Release Notes text");
        NSRange v213Range = NSMakeRange(0, [v213String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v213AttributedString = [[NSMutableAttributedString alloc] initWithString:v213String];
        [v213AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v213Range];
        [notesAttributedString appendAttributedString:v213AttributedString];
        
        // Release 2.1.2 — Bundle string
        NSString *v212String = NSLocalizedStringFromTableInBundle(@"v2.1.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.2 Release Notes text");
        NSRange v212Range = NSMakeRange(0, [v212String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v212AttributedString = [[NSMutableAttributedString alloc] initWithString:v212String];
        [v212AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v212Range];
        [notesAttributedString appendAttributedString:v212AttributedString];
        
        // Release 2.1.1 — Bundle string
        NSString *v211String = NSLocalizedStringFromTableInBundle(@"v2.1.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.1 Release Notes text");
        NSRange v211Range = NSMakeRange(0, [v211String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v211AttributedString = [[NSMutableAttributedString alloc] initWithString:v211String];
        [v211AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v211Range];
        [notesAttributedString appendAttributedString:v211AttributedString];
        
        // Release 2.1.0 — Bundle string
        NSString *v210String = NSLocalizedStringFromTableInBundle(@"v2.1.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.1.0 Release Notes text");
        NSRange v210Range = NSMakeRange(0, [v210String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v210AttributedString = [[NSMutableAttributedString alloc] initWithString:v210String];
        [v210AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v210Range];
        [notesAttributedString appendAttributedString:v210AttributedString];
        
        // Release 2.0.4 — Bundle string
        NSString *v204String = NSLocalizedStringFromTableInBundle(@"v2.0.4_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.4 Release Notes text");
        NSRange v204Range = NSMakeRange(0, [v204String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v204AttributedString = [[NSMutableAttributedString alloc] initWithString:v204String];
        [v204AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v204Range];
        [notesAttributedString appendAttributedString:v204AttributedString];
        
        // Release 2.0.3 — Bundle string
        NSString *v203String = NSLocalizedStringFromTableInBundle(@"v2.0.3_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.3 Release Notes text");
        NSRange v203Range = NSMakeRange(0, [v203String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v203AttributedString = [[NSMutableAttributedString alloc] initWithString:v203String];
        [v203AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v203Range];
        [notesAttributedString appendAttributedString:v203AttributedString];
        
        // Release 2.0.2 — Bundle string
        NSString *v202String = NSLocalizedStringFromTableInBundle(@"v2.0.2_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.2 Release Notes text");
        NSRange v202Range = NSMakeRange(0, [v202String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v202AttributedString = [[NSMutableAttributedString alloc] initWithString:v202String];
        [v202AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v202Range];
        [notesAttributedString appendAttributedString:v202AttributedString];
        
        // Release 2.0.1 — Bundle string
        NSString *v201String = NSLocalizedStringFromTableInBundle(@"v2.0.1_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.1 Release Notes text");
        NSRange v201Range = NSMakeRange(0, [v201String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v201AttributedString = [[NSMutableAttributedString alloc] initWithString:v201String];
        [v201AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v201Range];
        [notesAttributedString appendAttributedString:v201AttributedString];
        
        // Release 2.0.0 — Bundle string
        NSString *v200String = NSLocalizedStringFromTableInBundle(@"v2.0.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v2.0.0 Release Notes text");
        NSRange v200Range = NSMakeRange(0, [v200String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v200AttributedString = [[NSMutableAttributedString alloc] initWithString:v200String];
        [v200AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v200Range];
        [notesAttributedString appendAttributedString:v200AttributedString];
        
        // Release 1.0.0 — Bundle string
        NSString *v100String = NSLocalizedStringFromTableInBundle(@"v1.0.0_text", @"ReleaseNotes", [NSBundle mainBundle], @"v1.0.0 Release Notes text");
        NSRange v100Range = NSMakeRange(0, [v100String rangeOfString:@"\n"].location);
        NSMutableAttributedString *v100AttributedString = [[NSMutableAttributedString alloc] initWithString:v100String];
        [v100AttributedString addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:v100Range];
        [notesAttributedString appendAttributedString:v100AttributedString];
        
        self.textView.attributedText = notesAttributedString;
        self.textView.editable = NO;
        self.textView.allowsEditingTextAttributes = NO;
        self.textView.selectable = YES;

        [self addConstraints];
    }
    return self;
}

-(void)addConstraints
{
    NSDictionary *views = @{
                            @"title" : self.piwigoTitle,
                            @"by1" : self.byLabel1,
                            @"by2" : self.byLabel2,
                            @"usu" : self.versionLabel,
                            @"textView" : self.textView
                            };
    
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.piwigoTitle]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel1]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.byLabel2]];
    [self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.versionLabel]];
    
    // iPhone X ?
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    if ([deviceModel isEqualToString:@"iPhone10,3"] || [deviceModel isEqualToString:@"iPhone10,6"]) {
        // Add 25px for iPhone X (not great in landscape mode but temporary solution)
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-105-[title]-[by1][by2]-3-[usu]-10-[textView]-100-|"
                                   options:kNilOptions metrics:nil views:views]];
    } else {
        [self.view addConstraints:[NSLayoutConstraint
                                   constraintsWithVisualFormat:@"V:|-80-[title]-[by1][by2]-3-[usu]-10-[textView]-60-|"
                                   options:kNilOptions metrics:nil views:views]];
    }
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[textView]-15-|"
                                                                      options:kNilOptions
                                                                      metrics:nil
                                                                        views:views]];    
}

@end
