//
//  UploadService.m
//  piwigo
//
//  Created by Spencer Baker on 1/28/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadService.h"
#import "Model.h"
#import "ImageUpload.h"
#import "PiwigoTagData.h"
#import "CategoriesData.h"

@implementation UploadService

+(void)uploadImage:(NSData*)imageData
   withInformation:(NSDictionary*)imageInformation
			onProgress:(void (^)(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks))progress
		  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
			 onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	NSInteger chunkSize = 500 * 1024;
	
	NSInteger chunks = imageData.length / chunkSize;
	if(imageData.length % chunkSize != 0) {
		chunks++;
	}
	
	[self sendChunk:imageData WithInformation:[imageInformation mutableCopy]
                                    forOffset:0
                                      onChunk:0
                               forTotalChunks:(NSInteger)chunks
                                   onProgress:progress
                                 OnCompletion:completion
                                    onFailure:fail];
}

+(void)sendChunk:(NSData*)imageData
 WithInformation:(NSMutableDictionary*)imageInformation
					  forOffset:(NSInteger)offset
						onChunk:(NSInteger)count
				 forTotalChunks:(NSInteger)chunks
					 onProgress:(void (^)(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks))progress
				   OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
					  onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	NSInteger chunkSize = 500 * 1024;
	NSInteger length = [imageData length];
	NSUInteger thisChunkSize = length - offset > chunkSize ? chunkSize : length - offset;
	NSData *chunk = [imageData subdataWithRange:NSMakeRange(offset, thisChunkSize)];
	
	NSInteger nextChunkNumber = count + 1;
	offset += thisChunkSize;
	
	[imageInformation setObject:chunk forKey:kPiwigoImagesUploadParamData];
	[imageInformation setObject:[NSString stringWithFormat:@"%@", @(count)] forKey:kPiwigoImagesUploadParamChunk];
	[imageInformation setObject:[NSString stringWithFormat:@"%@", @(chunks)] forKey:kPiwigoImagesUploadParamChunks];
	
	[self postMultiPart:kPiwigoImagesUpload
          parameters:imageInformation
               progress:^(NSProgress *onProgress) {
                   dispatch_async(dispatch_get_main_queue(),
                                  ^(void){if(onProgress) progress((NSInteger)onProgress.completedUnitCount, (NSInteger)onProgress.totalUnitCount, count + 1, chunks);});
               }
             success:^(NSURLSessionTask *task, id responseObject) {
                 if(count >= chunks - 1) {
                      // done, return
                      if(completion) {
                          completion(task, responseObject);
                      }
                  } else {
                      // keep going!
                      [self sendChunk:imageData
                      WithInformation:imageInformation
                            forOffset:offset
                              onChunk:nextChunkNumber
                       forTotalChunks:chunks
                           onProgress:progress
                         OnCompletion:completion
                            onFailure:fail];
                  }
              } failure:^(NSURLSessionTask *task, NSError *error) {
                  // failed!
                  if(fail)
                  {
                      fail(task, error);
                  }
              }
  ];
}

+(NSURLSessionTask*)setImageInfoForImageWithId:(NSString*)imageId
                               withInformation:(NSDictionary*)imageInformation
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	
	NSString *tagIdList = [[[imageInformation objectForKey:kPiwigoImagesUploadParamTags]
                            valueForKey:@"description"] componentsJoinedByString:@", "];
	
	NSURLSessionTask *request = [self post:kPiwigoImageSetInfo
                             URLParameters:nil
                                parameters:@{
                                             @"method" : @"pwg.images.setInfo",
                                             @"image_id" : imageId,
                                             @"name" : [imageInformation objectForKey:kPiwigoImagesUploadParamName],
                                             @"author" : [imageInformation objectForKey:kPiwigoImagesUploadParamAuthor],
                                             @"comment" : [imageInformation objectForKey:kPiwigoImagesUploadParamDescription],
                                             @"tag_ids" : tagIdList,
                                             @"level" : [imageInformation objectForKey:kPiwigoImagesUploadParamPrivacy],
                                             @"single_value_mode" : @"replace"
                                             }
                                  progress:progress
                                   success:completion
                                   failure:fail];
	
	return request;
}

+(NSURLSessionTask*)getUploadedImageStatusById:(NSString*)imageId
                                    inCategory:(NSInteger)categoryId
                                    onProgress:(void (^)(NSProgress *))progress
                                  OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                                     onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	NSURLSessionTask *request = [self post:kCommunityImagesUploadCompleted
                             URLParameters:nil
                                parameters:@{
                                             @"pwg_token"   : [Model sharedInstance].pwgToken,
                                             @"image_id"    : imageId,
                                             @"category_id" : [NSString stringWithFormat:@"%@", @(categoryId)],
                                            }
                                  progress:progress
                                   success:completion
                                   failure:fail];
	
	return request;
}

+(NSURLSessionTask*)updateImageInfo:(ImageUpload*)imageInfo
                         onProgress:(void (^)(NSProgress *))progress
                       OnCompletion:(void (^)(NSURLSessionTask *task, NSDictionary *response))completion
                          onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail
{
	NSMutableArray *tagIds = [NSMutableArray new];
	for(PiwigoTagData *tagData in imageInfo.tags)
	{
		[tagIds addObject:@(tagData.tagId)];
	}
	
	NSDictionary *imageProperties = @{
									  kPiwigoImagesUploadParamName : imageInfo.imageUploadName,
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(imageInfo.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : imageInfo.author,
									  kPiwigoImagesUploadParamDescription : imageInfo.imageDescription,
									  kPiwigoImagesUploadParamTags : [tagIds copy]
									  };
	
	return [self setImageInfoForImageWithId:[NSString stringWithFormat:@"%@", @(imageInfo.imageId)]
                            withInformation:imageProperties
                                 onProgress:progress
                               OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
                                   
                                   // update the cache
                                   [[[CategoriesData sharedInstance] getCategoryById:imageInfo.categoryToUploadTo] updateCacheWithImageUploadInfo:imageInfo];
                                   
                                   if(completion)
                                   {
                                       completion(task, response);
                                   }
                               }
                                  onFailure:fail];
}

@end
