//
//  TagsService.m
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "TagsService.h"

@implementation TagsService

+(NSURLSessionTask*)getTagsOnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	return [self post:kPiwigoTagsGetList
		URLParameters:nil
           parameters:nil
             progress:nil
			  success:completion
			  failure:fail];
}

@end
