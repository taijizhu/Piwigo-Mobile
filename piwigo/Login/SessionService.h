//
//  SessionService.h
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"
#import <Foundation/Foundation.h>

@interface SessionService : NetworkHandler

+(NSURLSessionTask*)performLoginWithUser:(NSString*)user
                             andPassword:(NSString*)password
                            onCompletion:(void (^)(BOOL result, id response))completion
                               onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getStatusOnCompletion:(void (^)(NSDictionary *responseObject))completion
                                onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getPluginsListOnCompletion:(void (^)(NSDictionary *responseObject))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)sessionLogoutOnCompletion:(void (^)(NSURLSessionTask *task, BOOL sucessfulLogout))completion
                                    onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

@end