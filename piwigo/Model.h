//
//  Model.h
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "CategorySortViewController.h"

@class ALAssetsLibrary;

typedef enum {
	kPiwigoPrivacyEverybody = 0,
	kPiwigoPrivacyAdminsFamilyFriendsContacts = 1,
	kPiwigoPrivacyAdminsFamilyFriends = 2,
	kPiwigoPrivacyAdminsFamily = 4,
	kPiwigoPrivacyAdmins = 8,
	kPiwigoPrivacyCount = 5
} kPiwigoPrivacy;

#define kPiwigoPrivacyString(enum) [@[@"Everybody", @"Admins, Family, Friends, Contacts", @"Admins, Family, Friends", @"3: not assigned", @"Admins, Family", @"5: Count", @"6: not assigned", @"7: not assigned", @"Admins"] objectAtIndex:enum]

@interface Model : NSObject

+(Model*)sharedInstance;
-(void)saveToDisk;
+(ALAssetsLibrary*)defaultAssetsLibrary;

@property (nonatomic, strong) NSString *serverProtocol;
@property (nonatomic, strong) NSString *serverName;
@property (nonatomic, strong) NSString *pwgToken;
@property (nonatomic, strong) NSString *language;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, assign) BOOL hasAdminRights;

@property (nonatomic, assign) kPiwigoPrivacy defaultPrivacyLevel;
@property (nonatomic, strong) NSString *defaultAuthor;
@property (nonatomic, assign) BOOL resizeImageOnUpload;
@property (nonatomic, assign) NSInteger photoQuality;
@property (nonatomic, assign) NSInteger photoResize;
@property (nonatomic, assign) NSInteger defaultImagePreviewSize;

@property (nonatomic, assign) NSInteger imagesPerPage;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger lastPageImageCount;

@property (nonatomic, assign) NSInteger memoryCache;
@property (nonatomic, assign) NSInteger diskCache;

@property (nonatomic, assign) BOOL loadAllCategoryInfo;
@property (nonatomic, assign) kPiwigoSortCategory defaultSort;

-(NSString*)getNameForPrivacyLevel:(kPiwigoPrivacy)privacyLevel;

@end
