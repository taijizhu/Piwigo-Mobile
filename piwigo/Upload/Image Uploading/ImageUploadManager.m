//
//  ImageUploadManager.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>

#import "ImageUploadManager.h"
#import "PhotosFetch.h"
#import "ImageUpload.h"
#import "PiwigoTagData.h"
#import "ImageService.h"
#import "CategoriesData.h"

@interface ImageUploadManager()

@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign) NSInteger onCurrentImageUpload;
@property (nonatomic, assign) NSInteger current;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, assign) NSInteger currentChunk;
@property (nonatomic, assign) NSInteger totalChunks;
@property (nonatomic, assign) CGFloat iCloudProgress;

@end

@implementation ImageUploadManager

+(ImageUploadManager*)sharedInstance
{
	static ImageUploadManager *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
	});
	return instance;
}

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.imageUploadQueue = [NSMutableArray new];
		self.imageNamesUploadQueue = [NSMutableDictionary new];
        self.imageDeleteQueue = [NSMutableArray new];
		self.isUploading = NO;
        
        self.current = 0;
        self.total = 1;
        self.currentChunk = 1;
        self.totalChunks = 1;
	}
	return self;
}


#pragma mark -- Upload image queue management

-(void)addImages:(NSArray*)images
{
    for(ImageUpload *image in images)
    {
        [self addImage:image];
    }
}

-(void)addImage:(ImageUpload*)image
{
    [self.imageUploadQueue addObject:image];
	self.maximumImagesForBatch++;
	[self startUploadIfNeeded];
    
    // The file name extension may change e.g. MOV => MP4, HEIC => JPG
	[self.imageNamesUploadQueue setObject:image.image forKey:[image.image stringByDeletingPathExtension]];
}

-(void)startUploadIfNeeded
{
    if(!self.isUploading)
    {
        self.imageDeleteQueue = [NSMutableArray new];
        [self uploadNextImage];
    }
}

-(void)setIsUploading:(BOOL)isUploading
{
    _isUploading = isUploading;
    
    if(!isUploading)
    {
        // Reset variables
        self.maximumImagesForBatch = 0;
        self.onCurrentImageUpload = 1;

        // Allow system sleep
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
    else
    {
        // Prevent system sleep
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
}

-(void)setMaximumImagesForBatch:(NSInteger)maximumImagesForBatch
{
    _maximumImagesForBatch = maximumImagesForBatch;
    
    if([self.delegate respondsToSelector:@selector(imagesToUploadChanged:)])
    {
        [self.delegate imagesToUploadChanged:maximumImagesForBatch];
    }
}

-(NSInteger)getIndexOfImage:(ImageUpload*)image
{
    return [self.imageUploadQueue indexOfObject:image];
}

-(void)uploadNextImage
{
    // Another image or video to upload?
    if(self.imageUploadQueue.count <= 0)
    {
        self.isUploading = NO;
        return;
    }
    
    self.iCloudProgress = -1.0;         // No iCloud download (will become positive if any)
    self.isUploading = YES;
    [Model sharedInstance].hasUploadedImages = YES;
    
    // Image or video to be uploaded
    ImageUpload *nextImageToBeUploaded = [self.imageUploadQueue firstObject];
    NSString *fileExt = [[nextImageToBeUploaded.image pathExtension] lowercaseString];
    PHAsset *originalAsset = nextImageToBeUploaded.imageAsset;
    
    // Retrieve Photo, Live Photo or Video
    if (originalAsset.mediaType == PHAssetMediaTypeImage) {
        
        // Chek that the image format will be accepted by the Piwigo server
        if ((![[Model sharedInstance].uploadFileTypes containsString:fileExt]) &&
            (![[Model sharedInstance].uploadFileTypes containsString:@"jpg"]) ) {
            [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_format", @"Sorry, image files with extensions .%@ and .jpg are not accepted by the Piwigo server."), [fileExt uppercaseString]]
                         forRetrying:NO
                           withImage:nextImageToBeUploaded];
            return;
        }
        
        // Image file type accepted
        switch (originalAsset.mediaSubtypes) {
//            case PHAssetMediaSubtypePhotoLive:
//                [self retrieveFullSizeAssetDataFromLivePhoto:nextImageToBeUploaded];
//                break;
            case PHAssetMediaSubtypeNone:
            case PHAssetMediaSubtypePhotoPanorama:
            case PHAssetMediaSubtypePhotoHDR:
            case PHAssetMediaSubtypePhotoScreenshot:
            case PHAssetMediaSubtypePhotoLive:
            case PHAssetMediaSubtypePhotoDepthEffect:
            default:                                            // Case of GIF image
                // Image upload allowed — Will wait for image file download from iCloud if necessary
                [self retrieveFullSizeAssetDataFromImage:nextImageToBeUploaded];
                break;
        }
    }
    else if (originalAsset.mediaType == PHAssetMediaTypeVideo) {

        // Videos are always exported in MP4 format (whenever possible)
        fileExt = @"mp4";
        nextImageToBeUploaded.image = [[nextImageToBeUploaded.image stringByDeletingPathExtension] stringByAppendingPathExtension:fileExt];

        // Chek that the video format is accepted by the Piwigo server
        if (![[Model sharedInstance].uploadFileTypes containsString:fileExt]) {
            [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_format", @"Sorry, video files with extension .%@ are not accepted by the Piwigo server."), [fileExt uppercaseString]]
                         forRetrying:NO
                           withImage:nextImageToBeUploaded];
            return;
        }
        
        // Video upload allowed — Will wait for video file download from iCloud if necessary
        [self retrieveFullSizeAssetDataFromVideo:nextImageToBeUploaded];
    }
    else if (originalAsset.mediaType == PHAssetMediaTypeAudio) {

        // Not managed by Piwigo iOS yet…
        [self showErrorWithTitle:NSLocalizedString(@"audioUploadError_title", @"Audio Upload Error")
                      andMessage:NSLocalizedString(@"audioUploadError_format", @"Sorry, audio files are not supported by Piwigo Mobile yet.")
                     forRetrying:NO
                       withImage:nextImageToBeUploaded];
        return;

        // Chek that the audio format is accepted by the Piwigo server
//        if (![[Model sharedInstance].uploadFileTypes containsString:fileExt]) {
//            [self showErrorWithTitle:NSLocalizedString(@"audioUploadError_title", @"Audio Upload Error")
//                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"audioUploadError_format", @"Sorry, audio files with extension .%@ are not accepted by the Piwigo server."), [fileExt uppercaseString]]
//                         forRetrying:NO
//                           withImage:nextImageToBeUploaded];
//            return;
//        }

        // Audio upload allowed — Will wait for audio file download from iCloud if necessary
//        [self retrieveFullSizeAssetDataFromAudio:nextImageToBeUploaded];
    }
}

-(void)uploadNextImageAndRemoveImageFromQueue:(ImageUpload *)image withResponse:(NSDictionary *)response
{
    // Remove image from queue (in both tables)
    [self.imageUploadQueue removeObjectAtIndex:0];
    [self.imageNamesUploadQueue removeObjectForKey:[image.image stringByDeletingPathExtension]];

    // Update progress infos
    if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
    {
        [self.delegate imageUploaded:image placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:response];
    }
    
    // Upload next image
    [self uploadNextImage];
}


#pragma mark -- Image, retrieve and modify before upload

-(void)retrieveFullSizeAssetDataFromImage:(ImageUpload *)image  // Asynchronous
{
#if defined(DEBUG)
    NSLog(@"retrieveFullSizeAssetDataFromImage starting...");
#endif
    // Case of an image…
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    // Does not block the calling thread until image data is ready or an error occurs
    options.synchronous = NO;
    // Requests the most recent version of the image asset
    options.version = PHImageRequestOptionsVersionCurrent;
    // Requests the highest-quality image available, regardless of how much time it takes to load.
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    // Photos can download the requested video from iCloud
    options.networkAccessAllowed = YES;

    // The block Photos calls periodically while downloading the photo
    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* info) {
#if defined(DEBUG)
        NSLog(@"downloading Photo from iCloud — progress %lf",progress);
#endif
        // The handler needs to update the user interface => Dispatch to main thread
        dispatch_async(dispatch_get_main_queue(), ^{

            self.iCloudProgress = progress;
            ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
            if (error) {
                // Inform user and propose to cancel or continue
                [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                              andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_iCloud", @"Could not retrieve image from iCloud. Error: %@"), [error localizedDescription]]
                             forRetrying:YES
                               withImage:image];
                return;
            }
            else if (imageBeingUploaded.stopUpload) {
                // User wants to cancel the download
                *stop = YES;
                
                // Remove image from queue, update UI and upload next one
                self.maximumImagesForBatch--;
                [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
            }
            else {
                // Update progress bar(s)
                if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:)])
                {
                    [self.delegate imageProgress:image onCurrent:self.current forTotal:self.total onChunk:self.currentChunk forChunks:self.totalChunks iCloudProgress:progress];
                }
            }
        });
    };

    // Requests image…
    @autoreleasepool {
        [[PHImageManager defaultManager] requestImageDataForAsset:image.imageAsset options:options
                     resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
#if defined(DEBUG)
                         NSLog(@"retrieveFullSizeAssetDataFromImage \"%@\" returned info(%@)", image.image, info);
#endif
                         if ([info objectForKey:PHImageErrorKey]) {
                             NSError *error = [info valueForKey:PHImageErrorKey];
                             // Inform user and propose to cancel or continue
                             [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                                           andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_iCloud", @"Could not retrieve image from iCloud. Error: %@"), [error localizedDescription]]
                                          forRetrying:YES
                                            withImage:image];
                             return;
                         }

                         // Expected resource available
                         assert(imageData.length != 0);
                         [self modifyImage:image withData:imageData];
                     }
         ];
    }
}

-(void)modifyImage:(ImageUpload *)image withData:(NSData *)originalData
{
    // Create CGI reference from asset
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) originalData, NULL);
    if (!source) {
//#if defined(DEBUG)
//        NSLog(@"Error: Could not create source");
//#endif
    // Inform user and propose to cancel or continue
    [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                  andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), NSLocalizedString(@"imageUploadError_source", @"cannot create image source")]
                 forRetrying:YES
                   withImage:image];
        return;
    }
    
    // Get metadata of image before removing GPS metadata or resizing image
    NSMutableDictionary *assetMetadata = [(NSMutableDictionary*) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) mutableCopy];
//#if defined(DEBUG)
//    NSLog(@"modifyImage finds metadata :%@",assetMetadata);
//#endif

    // Strips GPS metadata if user requested it in Settings
    if([Model sharedInstance].stripGPSdataOnUpload && (assetMetadata != nil)) {
        
        // GPS dictionary
        NSMutableDictionary *GPSDictionary = [[assetMetadata objectForKey:(NSString *)kCGImagePropertyGPSDictionary] mutableCopy];
        if (GPSDictionary) {
//#if defined(DEBUG)
//            NSLog(@"modifyImage: GPS metadata = %@",GPSDictionary);
//#endif
            [assetMetadata removeObjectForKey:(NSString *)kCGImagePropertyGPSDictionary];
        }
        
        // EXIF dictionary
        NSMutableDictionary *EXIFDictionary = [[assetMetadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
        if (EXIFDictionary) {
//#if defined(DEBUG)
//            NSLog(@"modifyImage: EXIF User Comment metadata = %@",[EXIFDictionary valueForKey:(NSString *)kCGImagePropertyExifUserComment]);
//            NSLog(@"modifyImage: EXIF Subject Location metadata = %@",[EXIFDictionary valueForKey:(NSString *)kCGImagePropertyExifSubjectLocation]);
//#endif
            [EXIFDictionary removeObjectForKey:(NSString *)kCGImagePropertyExifUserComment];
            [EXIFDictionary removeObjectForKey:(NSString *)kCGImagePropertyExifSubjectLocation];
            [assetMetadata setObject:EXIFDictionary forKey:(NSString *)kCGImagePropertyExifDictionary];
        }

        // Final metadata…
//#if defined(DEBUG)
//        NSLog(@"modifyImage: w/o private metadata => %@",assetMetadata);
//#endif
    }

    // Get original image
    UIImage *assetImage = [UIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source, 0, NULL)];

    // Resize image if user requested it in Settings
    UIImage *imageResized = nil;
    if ([Model sharedInstance].resizeImageOnUpload && ([Model sharedInstance].photoResize < 100.0)) {
        // Resize image
        CGFloat scale = [Model sharedInstance].photoResize / 100.0;
        CGSize newImageSize = CGSizeApplyAffineTransform(assetImage.size, CGAffineTransformMakeScale(scale, scale));
        imageResized = [self scaleImage:assetImage toSize:newImageSize contentMode:UIViewContentModeScaleAspectFit];

        // Change metadata for new size
        [assetMetadata setObject:@(imageResized.size.height) forKey:(NSString *)kCGImagePropertyPixelHeight];
        [assetMetadata setObject:@(imageResized.size.width) forKey:(NSString *)kCGImagePropertyPixelWidth];
    } else {
        imageResized = [assetImage copy];
    }
    
    // Apply compression if user requested it in Settings, or convert to JPEG if necessary
    NSData *imageCompressed = nil;
    NSString *fileExt = [[image.image pathExtension] lowercaseString];
    if ([Model sharedInstance].compressImageOnUpload && ([Model sharedInstance].photoQuality < 100.0)) {
        // Compress image (only possible in JPEG)
        CGFloat compressionQuality = [Model sharedInstance].photoQuality / 100.0;
        imageCompressed = UIImageJPEGRepresentation(imageResized, compressionQuality);

        // Final image file will be in JPEG format
        image.image = [[image.image stringByDeletingPathExtension] stringByAppendingPathExtension:@"JPG"];
    } else if (![[Model sharedInstance].uploadFileTypes containsString:fileExt]) {
        // Image in unaccepted file format for Piwigo server => convert to JPEG format
        imageCompressed = UIImageJPEGRepresentation(imageResized, 100.0);
        
        // Final image file will be in JPEG format
        image.image = [[image.image stringByDeletingPathExtension] stringByAppendingPathExtension:@"JPG"];
    }
    
    // If compression failed or imageCompressed null, try to use original image
    if (!imageCompressed) {
        CFStringRef UTI = CGImageSourceGetType(source);
        CFMutableDataRef imageDataRef = CFDataCreateMutable(nil, 0);
        CGImageDestinationRef destination = CGImageDestinationCreateWithData(imageDataRef, UTI, 1, nil);
        CGImageDestinationAddImage(destination, imageResized.CGImage, nil);
        if(!CGImageDestinationFinalize(destination)) {
//    #if defined(DEBUG)
//            NSLog(@"Error: Could not retrieve imageData object");
//    #endif
            CFRelease(source);
            CFRelease(destination);
            CFRelease(imageDataRef);
            // Inform user and propose to cancel or continue
            [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), NSLocalizedString(@"imageUploadError_destination", @"cannot create image destination")]
                         forRetrying:YES
                           withImage:image];
            return;
        }
        imageCompressed = (__bridge  NSData *)imageDataRef;
        CFRelease(imageDataRef);
        CFRelease(destination);
        assetMetadata = nil;
        assetImage = nil;
    }
    
    // Release original CGImageSourceRef
    CFRelease(source);
    
    // Add metadata to final image
    NSData *imageData = [self writeMetadataIntoImageData:imageCompressed metadata:assetMetadata];
    
    // Release memory
    assetMetadata = nil;
    assetImage = nil;

    // Prepare MIME type
    NSString *mimeType = @"";
    mimeType = [self contentTypeForImageData:imageData];

    // Upload image with tags and properties
    [self uploadImage:image withData:imageData andMimeType:mimeType];
}

-(NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
    }
    return nil;
}

//-(void)retrieveFullSizeAssetDataFromLivePhoto:(ImageUpload *)image   // Asynchronous
//{
//    __block NSData *assetData = nil;
//
//    // Case of an Live Photo…
//    PHLivePhotoRequestOptions *options = [[PHLivePhotoRequestOptions alloc] init];
//    // Requests the most recent version of the image asset
//    options.version = PHImageRequestOptionsVersionOriginal;
//    // Requests the highest-quality image available, regardless of how much time it takes to load.
//    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
//    // Photos can download the requested video from iCloud.
//    options.networkAccessAllowed = YES;
//    // The block Photos calls periodically while downloading the LivePhoto.
//    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
//        NSLog(@"downloading Live Photo from iCloud — progress %lf",progress);
//    };
//
//    // Requests Live Photo…
//    @autoreleasepool {
//        [[PHImageManager defaultManager] requestLivePhotoForAsset:image.imageAsset
//                   targetSize:CGSizeZero contentMode:PHImageContentModeDefault
//                      options:options resultHandler:^(PHLivePhoto *livePhoto, NSDictionary *info) {
//#if defined(DEBUG)
//                          NSLog(@"retrieveFullSizeAssetDataFromLivePhoto returned info(%@)", info);
//#endif
//                          if ([info objectForKey:PHImageErrorKey]) {
//                              NSError *error = [info valueForKey:PHImageErrorKey];
//                              NSLog(@"=> Error : %@", error.description);
//                          }
//
//                          if (![[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
//                              // Expected resource available
//                              NSArray<PHAssetResource*>* resources = [PHAssetResource assetResourcesForLivePhoto:livePhoto];
//                              // Extract still high resolution image and original video
//                              __block PHAssetResource *resImage = nil;
//                              [resources enumerateObjectsUsingBlock:^(PHAssetResource *res, NSUInteger idx, BOOL *stop) {
//                                  if (res.type == PHAssetResourceTypeFullSizePhoto) {
//                                      resImage = res;
//                                  }
//                              }];
//
//                              // Store resources
//                              NSURL *urlImage = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[image.image stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"]]];
//
//                              // Deletes temporary file if exists (might be incomplete, etc.)
//                              [[NSFileManager defaultManager] removeItemAtURL:urlImage error:nil];
//
//                              // Store temporarily still image and video, then extract data
//                              [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resImage toFile:urlImage options:nil completionHandler:^(NSError * _Nullable error) {
//                                      if (error.code) {
//                                          NSLog(@"=> Error storing image: %@", error.description);
//                                      }
//                                      assetData = [[NSData dataWithContentsOfURL:urlImage] copy];
//                                      assert(assetData.length != 0);
//                                      // Modify image before upload if needed
//                                      [self modifyImage:image withData:assetData];
//                              }];
//                          }
//                      }
//         ];
//    }
//}

#pragma mark -- Video, retrieve and modify before upload

-(void)retrieveFullSizeAssetDataFromVideo:(ImageUpload *)image  // Asynchronous
{
    // Case of a video…
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    // Requests the most recent version of the image asset
    options.version = PHVideoRequestOptionsVersionCurrent;
    // Requests the highest-quality video available, regardless of how much time it takes to load.
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
    // Photos can download the requested video from iCloud.
    options.networkAccessAllowed = YES;

    // The block Photos calls periodically while downloading the video.
    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
#if defined(DEBUG)
        NSLog(@"downloading Video from iCloud — progress %lf",progress);
#endif
        // The handler needs to update the user interface => Dispatch to main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.iCloudProgress = progress;
            ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
            if (error) {
                // Inform user and propose to cancel or continue
                [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                              andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_iCloud", @"Could not retrieve video from iCloud. Error: %@"), [error localizedDescription]]
                             forRetrying:YES
                               withImage:image];
                return;
            }
            else if (imageBeingUploaded.stopUpload) {
                // User wants to cancel the download
                *stop = YES;
                
                // Remove image from queue and upload next one
                self.maximumImagesForBatch--;
                [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
            }
            else {
                // Updates progress bar(s)
                if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:)])
                {
                    NSLog(@"retrieveFullSizeAssetDataFromVideo: %.2f", progress);
                    [self.delegate imageProgress:image onCurrent:self.current forTotal:self.total onChunk:self.currentChunk forChunks:self.totalChunks iCloudProgress:progress];
                }
            }
        });
    };
    
    // Available export session presets?
    [[PHImageManager defaultManager] requestAVAssetForVideo:image.imageAsset
                options:options
          resultHandler:^(AVAsset *avasset, AVAudioMix *audioMix, NSDictionary *info) {

              // QuickTime video exportable with passthrough option (e.g. recorded with device)?
              [AVAssetExportSession determineCompatibilityOfExportPreset:AVAssetExportPresetPassthrough withAsset:avasset outputFileType:AVFileTypeMPEG4 completionHandler:^(BOOL compatible) {
            
                      NSString *exportPreset = nil;
                      if (compatible) {
                          // No reencoding required — will keep metadata (or not depending on user's settings)
                          exportPreset = AVAssetExportPresetPassthrough;
                      }
                      else
                      {
                          NSInteger maxPixels = lround(fmax(image.imageAsset.pixelWidth, image.imageAsset.pixelHeight));
                          NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avasset];
                          // This array never contains AVAssetExportPresetPassthrough,
                          // that is why we use determineCompatibilityOfExportPreset: before.
//                          NSLog(@"exportPresetsCompatibleWithAsset: %@", presets);
                          if ((maxPixels <= 640) && ([presets containsObject:AVAssetExportPreset640x480])) {
                              // Encode in 640x480 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset640x480;
                          }
                          else if ((maxPixels <= 960) && ([presets containsObject:AVAssetExportPreset960x540])) {
                              // Encode in 960x540 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset960x540;
                          }
                          else if ((maxPixels <= 1280) && ([presets containsObject:AVAssetExportPreset1280x720])) {
                              // Encode in 1280x720 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset1280x720;
                          }
                          else if ((maxPixels <= 1920) && ([presets containsObject:AVAssetExportPreset1920x1080])) {
                              // Encode in 1920x1080 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset1920x1080;
                          }
                          else {
                              // Use highest quality for device
                              exportPreset = AVAssetExportPresetHighestQuality;
                          }
                      }

                  // Requests video with selected export preset…
                  @autoreleasepool {
                      [[PHImageManager defaultManager] requestExportSessionForVideo:image.imageAsset options:options
                               exportPreset:exportPreset
                              resultHandler:^(AVAssetExportSession * _Nullable exportSession, NSDictionary * _Nullable info) {
#if defined(DEBUG)
                                  NSLog(@"retrieveFullSizeAssetDataFromVideo returned info(%@)", info);
#endif
                                  // The handler needs to update the user interface => Dispatch to main thread
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      if ([info objectForKey:PHImageErrorKey]) {
                                          // Inform user and propose to cancel or continue
                                          NSError *error = [info valueForKey:PHImageErrorKey];
                                          [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                                                        andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_iCloud", @"Could not retrieve video from iCloud. Error: %@"), [error localizedDescription]]
                                                       forRetrying:YES
                                                         withImage:image];
                                          return;
                                      }
                                  });
                                  
//                                  if ([[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
//                                      // This is a degraded version, wait for the next one…
//                                      return;
//                                  }
                                  
                                  // Modifies video before upload to Piwigo server
                                  [self modifyVideo:image withAVAsset:avasset beforeExporting:exportSession];
//                                  [self modifyVideo:image beforeExporting:exportSession];
                              }
                       ];
                  }
              }];
    }];
}

-(void)modifyVideo:(ImageUpload *)image withAVAsset:(AVAsset *)originalVideo beforeExporting:(AVAssetExportSession *)exportSession
{
    // Strips private metadata if user requested it in Settings
    // Apple documentation: 'metadataItemFilterForSharing' removes user-identifying metadata items, such as location information and leaves only metadata releated to commerce or playback itself. For example: playback, copyright, and commercial-related metadata, such as a purchaser’s ID as set by a vendor of digital media, along with metadata either derivable from the media itself or necessary for its proper behavior are all left intact.
    [exportSession setMetadata:nil];
    if ([Model sharedInstance].stripGPSdataOnUpload) {
        [exportSession setMetadataItemFilter:[AVMetadataItemFilter metadataItemFilterForSharing]];
    } else {
        [exportSession setMetadataItemFilter:nil];
    }

    // Complete video range
    [exportSession setTimeRange:CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)];

    // Video formats — Always export video in MP4 format
    [exportSession setOutputFileType:AVFileTypeMPEG4];
    [exportSession setShouldOptimizeForNetworkUse:YES];
#if defined(DEBUG)
    NSLog(@"Supported file types: %@", exportSession.supportedFileTypes);
    NSLog(@"Description: %@", exportSession.description);
#endif

    // Prepare MIME type
    NSString *mimeType = @"video/mp4";

    // Temporary filename and path
    [exportSession setOutputURL:[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[image.image stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp4"]]]];

    // Deletes temporary video file if exists (might be incomplete, etc.)
    [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];

    // Export temporary video for upload
    __block NSData *assetData = nil;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([exportSession status] == AVAssetExportSessionStatusCompleted)
            {
                // Gets copy as NSData
                assetData = [[NSData dataWithContentsOfURL:exportSession.outputURL] copy];
                assert(assetData.length != 0);
//#if defined(DEBUG)
//                AVAsset *videoAsset = [AVAsset assetWithURL:exportSession.outputURL];
//                NSArray *assetMetadata = [videoAsset commonMetadata];
//                NSLog(@"Export sucess :-)");
//                NSLog(@"Video metadata: %@", assetMetadata);
//#endif

                // Deletes temporary video file
                [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];

                // Upload video with tags and properties
                [self uploadImage:image withData:assetData andMimeType:mimeType];
            }
            else if ([exportSession status] == AVAssetExportSessionStatusFailed)
            {
                // Deletes temporary video file if any
                [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];
                
                // Try to upload original file
                if ([originalVideo isKindOfClass:[AVURLAsset class]] &&
                    [[Model sharedInstance].uploadFileTypes containsString:[image.image pathExtension]]) {
                    AVURLAsset *originalFileURL = (AVURLAsset *)originalVideo;
                    NSData *assetData = [[NSData dataWithContentsOfURL:originalFileURL.URL] copy];
                    NSArray *assetMetadata = [originalVideo commonMetadata];

                    // Creates metadata without location data
                    NSMutableArray *newAssetMetadata = [NSMutableArray array];
                    for (AVMetadataItem *item in assetMetadata) {
                        if ([item.commonKey isEqualToString:AVMetadataCommonKeyLocation]){
#if defined(DEBUG)
                            NSLog(@"Location found: %@", item.stringValue);
#endif
                        } else {
                            [newAssetMetadata addObject:item];
                        }
                    }
                    BOOL assetDoesNotContainGPSmetadata =
                        (newAssetMetadata.count == assetMetadata.count) || ([assetMetadata count] == 0);

                    if (assetData && ((![Model sharedInstance].stripGPSdataOnUpload) || ([Model sharedInstance].stripGPSdataOnUpload && assetDoesNotContainGPSmetadata))) {

                        // Upload video with tags and properties
                        [self uploadImage:image withData:assetData andMimeType:mimeType];
                        return;
                    } else {
                        // No data — Inform user that it won't succeed
                        [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                                      andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_export", @"Sorry, the video could not be retrieved for the upload. Error: %@"), exportSession.error.localizedDescription]
                                     forRetrying:NO
                                       withImage:image];
                        return;
                    }
                }
            }
            else if ([exportSession status] == AVAssetExportSessionStatusCancelled)
            {
                // Deletes temporary video file
                [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];

                // Inform user
                [self showErrorWithTitle:NSLocalizedString(@"uploadCancelled_title", @"Upload Cancelled")
                              andMessage:NSLocalizedString(@"videoUploadCancelled_message", @"The upload of the video has been cancelled.")
                             forRetrying:YES
                               withImage:image];
                return;
            }
            else    // Failed for unknown reason!
            {
                // Deletes temporary video files
                [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];

                // Inform user
                [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                              andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_unknown", @"Sorry, the upload of the video has failed for an unknown error during the MP4 conversion. Error: %@"), exportSession.error.localizedDescription]
                             forRetrying:YES
                               withImage:image];
                return;
            }
        });
    }];
}

// The creation date is kept when copying the MOV video file and uploading it with MP4 extension in Piwigo
// However, it is replaced when exporting the file in Piwigo while the metadata is correct.
// With this method, the thumbnail is produced correctly

//-(void)retrieveFullSizeAssetDataFromVideo:(ImageUpload *)image withMimeType:(NSString *)mimeType  // Asynchronous
//{
//    // Case of a video…
//    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
//    // Requests the most recent version of the image asset
//    options.version = PHVideoRequestOptionsVersionCurrent;
//    // Requests the highest-quality video available, regardless of how much time it takes to load.
//    options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
//    // Photos can download the requested video from iCloud.
//    options.networkAccessAllowed = YES;
//    // The block Photos calls periodically while downloading the video.
//    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
//        NSLog(@"downloading Video from iCloud — progress %lf",progress);
//    };
//
//    // Requests video…
//    @autoreleasepool {
//        [[PHImageManager defaultManager] requestAVAssetForVideo:image.imageAsset options:options
//              resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
//#if defined(DEBUG)
//                  NSLog(@"retrieveFullSizeAssetDataFromVideo returned info(%@)", info);
//#endif
//                  // Error encountered while retrieving asset?
//                  if ([info objectForKey:PHImageErrorKey]) {
//                      NSError *error = [info valueForKey:PHImageErrorKey];
//#if defined(DEBUG)
//                      NSLog(@"=> Error : %@", error.description);
//#endif
//                  }
//
//                  // We don't accept degraded assets
//                  if ([[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
//                      // This is a degraded version, wait for the next one…
//                      return;
//                  }
//
//                  // Location of temporary video file
//                  NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:image.image]];
//
//                  // Deletes temporary file if exists already (might be incomplete, etc.)
//                  [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//
//                  // Writes to documents folder before uploading to Piwigo server
//                  if ([asset isKindOfClass:[AVURLAsset class]]) {
//
//                      // Simple video
//                      AVURLAsset *avurlasset = (AVURLAsset*) asset;
//                      NSLog(@"avurlasset=%@", avurlasset.URL.absoluteString);
//
//                      // Creates temporary video file and modify it as needed
//                      NSError *error;
//                      if ([[NSFileManager defaultManager] copyItemAtURL:avurlasset.URL toURL:fileURL error:&error]) {
//                          // Modifies video before upload to Piwigo server
//                          [self modifyVideo:image atURL:fileURL withMimeType:mimeType];
//                      } else {
//                          // Could not copy the video file!
//#if defined(DEBUG)
//                          NSLog(@"=> Error : %@", error.description);
//#endif
//                      }
//                  } else if ([asset isKindOfClass:[AVComposition class]]) {
//
////                      NSURL *avurlasset = [NSURL fileURLWithPath:@"/var/mobile/Media/DCIM/105APPLE/IMG_5374.MOV"];
////                      NSLog(@"avurlasset=%@", avurlasset.absoluteString);
////
////                      // Creates temporary video file and modify it as needed
////                      NSError *error;
////                      if ([[NSFileManager defaultManager] copyItemAtURL:avurlasset toURL:fileURL error:&error]) {
////                          // Modifies video before upload to Piwigo server
////                          [self modifyVideo:image atURL:fileURL withMimeType:mimeType];
////                      } else {
////                          // Could not copy the video file!
////#if defined(DEBUG)
////                          NSLog(@"=> Error : %@", error.description);
////#endif
////                      }
//
//                      // AVComposition object, e.g. a Slow-Motion video
//                      AVMutableComposition *avComp = [(AVComposition*) asset copy];
//
//                      // Export Slow-Mo as standard video
//                      AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avComp presetName:AVAssetExportPresetHighestQuality];
//                      [exportSession setOutputURL:fileURL];
//                      exportSession.outputFileType = AVFileTypeMPEG4;
////                      exportSession.outputFileType = AVFileTypeQuickTimeMovie;
//                      [exportSession setShouldOptimizeForNetworkUse:YES];
//                      [exportSession exportAsynchronouslyWithCompletionHandler:^{
//                          // Error ?
//                          if (exportSession.error) {
//                              NSLog(@"=> exportSession Status: %ld and Error: %@", (long)exportSession.status, exportSession.error.description);
//                              return;
//                          }
//
//                          // Modifies video before upload to Piwigo server
//                          [self modifyVideo:image atURL:exportSession.outputURL withMimeType:mimeType];
//                      }];
//                  }
//              }
//         ];
//    }
//}

//-(void)modifyVideo:(ImageUpload *)image atURL:(NSURL *)fileURL withMimeType:(NSString *)mimeType
//{
//    // Video and metadata from asset
//    __block NSData *assetData = nil;
//    AVAsset *videoAsset = [AVAsset assetWithURL:fileURL];
//    NSArray *assetMetadata = [videoAsset commonMetadata];
//
//    // Strips GPS data if user requested it in Settings
//    if (![Model sharedInstance].stripGPSdataOnUpload || ([assetMetadata count] == 0)) {
//
//        // Gets copy as NSData
//        assetData = [[NSData dataWithContentsOfURL:fileURL] copy];
//        assert(assetData.length != 0);
//
//        // Deletes temporary video file
//        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//
//        // Upload video with tags and properties
//        [self uploadImage:image withData:assetData andMimeType:mimeType];
//    }
//    else
//    {
//        // Creates metadata without location data
//        NSMutableArray *newAssetMetadata = [NSMutableArray array];
//        for (AVMetadataItem *item in assetMetadata) {
//            if ([item.commonKey isEqualToString:AVMetadataCommonKeyLocation]){
//#if defined(DEBUG)
//                NSLog(@"Location found: %@", item.stringValue);
//#endif
//            } else {
//                [newAssetMetadata addObject:item];
//            }
//        }
//
//        // Done if metadata did not contain location
//        if (newAssetMetadata.count == assetMetadata.count) {
//
//            // Gets copy as NSData
//            assetData = [[NSData dataWithContentsOfURL:fileURL] copy];
//            assert(assetData.length != 0);
//
//            // Deletes temporary video file
//            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//
//            // Upload video with tags and properties
//            [self uploadImage:image withData:assetData andMimeType:mimeType];
//        }
//        else if ([videoAsset isExportable]) {
//
//            // Export new asset from original asset
//            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:videoAsset presetName:AVAssetExportPresetPassthrough];
//            NSLog(@"exportSession (before): %@", exportSession);
//            NSLog(@"Supported file types: %@", exportSession.supportedFileTypes);
//
//            // Filename is ("_" + name + ".mp4") in same directory
//            NSURL *newFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[@"_" stringByAppendingString:[image.image stringByDeletingPathExtension]] stringByAppendingPathExtension:@"mp4"]]];
//            exportSession.outputURL = newFileURL;
//            if ([exportSession.supportedFileTypes containsObject:AVFileTypeMPEG4]) {
//                exportSession.outputFileType = AVFileTypeMPEG4;
//            } else {
//                exportSession.outputFileType = AVFileTypeQuickTimeMovie;
//            }
//            exportSession.shouldOptimizeForNetworkUse = YES;
////            exportSession.fileLengthLimit ??
//
//            // Deletes temporary file if exists already (might be incomplete, etc.)
//            [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//            // Video range
//            CMTime start = kCMTimeZero;
//            CMTimeRange range = CMTimeRangeMake(start, [videoAsset duration]);
//            exportSession.timeRange = range;
//
//            // Updated metadata
//            exportSession.metadata = newAssetMetadata;
//
//            // Export video
//            [exportSession exportAsynchronouslyWithCompletionHandler:^{
//                if ([exportSession status] == AVAssetExportSessionStatusCompleted)
//                {
//#if defined(DEBUG)
//                    NSLog(@"Export sucess…");
//#endif
//                    // Gets copy as NSData
//                    assetData = [[NSData dataWithContentsOfURL:newFileURL] copy];
//                    AVAsset *videoAsset = [AVAsset assetWithURL:newFileURL];
//                    NSArray *assetMetadata = [videoAsset commonMetadata];
//                    NSLog(@"Video metadata: %@", assetMetadata);
//                    assert(assetData.length != 0);
//
//                    // Deletes temporary video files
//                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//                    // Upload video with tags and properties
//                    [self uploadImage:image withData:assetData andMimeType:mimeType];
//                }
//                else if ([exportSession status] == AVAssetExportSessionStatusFailed)
//                {
//#if defined(DEBUG)
//                    NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
//#endif
//                    // Deletes temporary video files
//                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//                }
//                else if ([exportSession status] == AVAssetExportSessionStatusCancelled)
//                {
//#if defined(DEBUG)
//                    NSLog(@"Export canceled");
//#endif
//                    // Deletes temporary video files
//                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//                }
//                else
//                {
//#if defined(DEBUG)
//                    NSLog(@"Export ??");
//#endif
//                    // Deletes temporary video files
//                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//                }
//            }];
//        }
//        else {
//            // Could not export a new video — What to do?
//        }
//    }
//}


#pragma mark -- Upload image/video

-(void)uploadImage:(ImageUpload *)image withData:(NSData *)imageData andMimeType:(NSString *)mimeType
{
	// Check that title is not empty (should never happen)
    if ([image.title length] == 0) image.title = @"Image";
        
    // Append Tags
	NSMutableArray *tagIds = [NSMutableArray new];
	for(PiwigoTagData *tagData in image.tags)
	{
		[tagIds addObject:@(tagData.tagId)];
	}
	
    // Prepare properties for upload
	NSDictionary *imageProperties = @{
									  kPiwigoImagesUploadParamFileName : image.image,
									  kPiwigoImagesUploadParamTitle : image.title,
									  kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(image.categoryToUploadTo)],
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(image.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : image.author,
									  kPiwigoImagesUploadParamDescription : image.imageDescription,
									  kPiwigoImagesUploadParamTags : [tagIds copy],
                                      kPiwigoImagesUploadParamMimeType : mimeType
									  };
	
    // Upload photo or video
	[UploadService uploadImage:imageData
			   withInformation:imageProperties
					onProgress:^(NSProgress *progress, NSInteger currentChunk, NSInteger totalChunks) {
                        ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
                        if (imageBeingUploaded.stopUpload) {
                            [progress cancel];
                        }
                        self.current = (NSInteger) progress.completedUnitCount;
                        self.total = (NSInteger) progress.totalUnitCount;
                        self.currentChunk = currentChunk;
                        self.totalChunks = totalChunks;
                        if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:)])
                        {
                            [self.delegate imageProgress:image onCurrent:self.current forTotal:self.total onChunk:currentChunk forChunks:totalChunks iCloudProgress:self.iCloudProgress];
                        }
					} OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
                        // Consider image job done
                        self.onCurrentImageUpload++;
						
                        // Set properties of uploaded image/video on Piwigo server
                        [self setImageResponse:response withInfo:imageProperties];
                        
						// The image must not be appended to the cache if it is moderated
                        if ([Model sharedInstance].usesCommunityPluginV29) {

                            // Append image to cache only if it is not moderated
                            [self isUploadedImageModerated:response inCategory:image.categoryToUploadTo];
                            
                        } else {
                            // Increment number of images in category
                            [[[CategoriesData sharedInstance] getCategoryById:image.categoryToUploadTo] incrementImageSizeByOne];
                            
                            // Read image/video information and update cache
                            [self addImageDataToCategoryCache:response];
                        }
                        
                        // Delete image from Photos library if requested
                        if ([Model sharedInstance].deleteImageAfterUpload) {
                            [self.imageDeleteQueue addObject:image.imageAsset];
                        }

                        dispatch_async(dispatch_get_main_queue(), ^{
                            // Remove image from queue and upload next one
                            [self uploadNextImageAndRemoveImageFromQueue:image withResponse:response];
                        });

					} onFailure:^(NSURLSessionTask *task, NSError *error) {
						ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
                        if (imageBeingUploaded.stopUpload) {
                            // Upload was cancelled by user
                            self.maximumImagesForBatch--;
                            // Remove image from queue and upload next one
                            [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
                        }
						else
						{
#if defined(DEBUG)
							NSLog(@"ERROR IMAGE UPLOAD: %@", error);
#endif
                            // Inform user and propose to cancel or continue
                            [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
                                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), [error localizedDescription]]
                                         forRetrying:YES
                                           withImage:image];
						}
					}];
}

-(void)showErrorWithTitle:(NSString *)title andMessage:(NSString *)message forRetrying:(BOOL)retry withImage:(ImageUpload *)image
{
    // Determine present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    // Present alert
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:title
                                message:message
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction * action) {
                                        // Consider image job done
                                        self.onCurrentImageUpload++;

                                        // Empty queue
                                        while (self.imageUploadQueue.count > 0) {
                                            self.onCurrentImageUpload++;
                                            ImageUpload *nextImage = [self.imageUploadQueue firstObject];
                                            [self.imageUploadQueue removeObjectAtIndex:0];
                                            [self.imageNamesUploadQueue removeObjectForKey:[nextImage.image stringByDeletingPathExtension]];
                                        }
                                        // Tell user how many images have been downloaded
                                        if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
                                        {
                                            [self.delegate imageUploaded:image placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:nil];
                                        }
                                        // Stop uploading
                                        self.isUploading = NO;
                                    }];
    
    if (retry) {
        // Retry to upload the image
        UIAlertAction* retryAction = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action) {
                                         // Upload image
                                         [self uploadNextImage];
                                     }];
        [alert addAction:retryAction];
    } else {
        // Upload next image
        UIAlertAction* nextAction = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"alertNextButton", @"Next Image")
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action) {
                                         // Consider image job done
                                         self.onCurrentImageUpload++;

                                         // Remove image from queue and upload next one
                                         [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
                                     }];
        [alert addAction:nextAction];
    }
    
    [alert addAction:dismissAction];
    [topViewController presentViewController:alert animated:YES completion:nil];
}


#pragma mark -- Finish image upload

-(void)setImageResponse:(NSDictionary*)jsonResponse withInfo:(NSDictionary*)imageProperties
{
	if([[jsonResponse objectForKey:@"stat"] isEqualToString:@"ok"])
	{
		NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
		NSString *imageId = [imageResponse objectForKey:@"image_id"];
		
        // Set properties of image on Piwigo server
		[UploadService setImageInfoForImageWithId:imageId
								  withInformation:imageProperties
									   onProgress:^(NSProgress *progress) {
										   // progress
									   } OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
										   // completion
									   } onFailure:^(NSURLSessionTask *task, NSError *error) {
										   // fail
									   }];
		
	}
}

-(void)isUploadedImageModerated:(NSDictionary*)jsonResponse inCategory:(NSInteger)categoryId
{
    if([[jsonResponse objectForKey:@"stat"] isEqualToString:@"ok"])
    {
        NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
        NSString *imageId = [imageResponse objectForKey:@"image_id"];
        
        // Determine if the uploaded image is moderated
        [UploadService getUploadedImageStatusById:imageId
                                       inCategory:categoryId
                                       onProgress:^(NSProgress *progress) {
                                           // progress
                                       }
                                    OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {

                                        if ([[response objectForKey:@"stat"] isEqualToString:@"ok"]) {
                                            
                                            // When admin trusts user, pending answer is empty
                                            id pendingStatus = [[response objectForKey:@"result"] objectForKey:@"pending"];
                                            if (pendingStatus && [pendingStatus count]) {
                                                
                                                id pendingState = [pendingStatus objectAtIndex:0];
                                                if ([[pendingState objectForKey:@"state"] isEqualToString:@"moderation_pending"]) {
                                                    
                                                    // Moderation pending => Don't add this uploaded image/video to cache now
                                                
                                                } else {    // No moderation pending
                                                    
                                                    // Increment number of images in category
                                                    [[[CategoriesData sharedInstance] getCategoryById:categoryId] incrementImageSizeByOne];

                                                    // Read image/video information and update cache
                                                    [self addImageDataToCategoryCache:jsonResponse];
                                                }
                                            } else {        // No pending status response ! Trusted user

                                                // Increment number of images in category
                                                [[[CategoriesData sharedInstance] getCategoryById:categoryId] incrementImageSizeByOne];
                                                
                                                // Read image/video information and update cache
                                                [self addImageDataToCategoryCache:jsonResponse];
                                            }
                                         }
                                    }
                                        onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                            NSLog(@"isUploadedImageModerated error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                        }
         ];
    }
}

-(void)addImageDataToCategoryCache:(NSDictionary*)jsonResponse
{
    if([[jsonResponse objectForKey:@"stat"] isEqualToString:@"ok"])
    {
        NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
        NSString *imageId = [imageResponse objectForKey:@"image_id"];
    
        // Read image information and update cache
        [ImageService getImageInfoById:[imageId integerValue]
                      ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                          //
                      } onFailure:^(NSURLSessionTask *task, NSError *error) {
                          //
                      }];
    }
}


#pragma mark -- Scale, crop, etc. image before upload

-(UIImage*)scaleImage:(UIImage*)image toSize:(CGSize)newSize contentMode:(UIViewContentMode)contentMode
{
    if (contentMode == UIViewContentModeScaleToFill)
    {
        return [self image:image byScalingToFillSize:newSize];
    }
    else if ((contentMode == UIViewContentModeScaleAspectFill) ||
             (contentMode == UIViewContentModeScaleAspectFit))
    {
        CGFloat horizontalRatio   = image.size.width  / newSize.width;
        CGFloat verticalRatio     = image.size.height / newSize.height;
        CGFloat ratio;
        
        if (contentMode == UIViewContentModeScaleAspectFill)
            ratio = MIN(horizontalRatio, verticalRatio);
        else
            ratio = MAX(horizontalRatio, verticalRatio);
        
        CGSize  sizeForAspectScale = CGSizeMake(image.size.width / ratio, image.size.height / ratio);
        
        UIImage *newImage = [self image:image byScalingToFillSize:sizeForAspectScale];
        
        // if we're doing aspect fill, then the image still needs to be cropped
        if (contentMode == UIViewContentModeScaleAspectFill)
        {
            CGRect  subRect = CGRectMake(floor((sizeForAspectScale.width - newSize.width) / 2.0),
                                         floor((sizeForAspectScale.height - newSize.height) / 2.0),
                                         newSize.width,
                                         newSize.height);
            newImage = [self image:newImage byCroppingToBounds:subRect];
        }
        
        return newImage;
    }
    
    return nil;
}
- (UIImage *)image:(UIImage*)image byCroppingToBounds:(CGRect)bounds
{
    CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], bounds);
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return croppedImage;
}
- (UIImage*)image:(UIImage*)image byScalingToFillSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

-(UIImage*)image:(UIImage*)image byScalingAspectFillSize:(CGSize)newSize
{
    return [self scaleImage:image toSize:newSize contentMode:UIViewContentModeScaleAspectFill];
}

-(UIImage*)image:(UIImage*)image byScalingAspectFitSize:(CGSize)newSize
{
    return [self scaleImage:image toSize:newSize contentMode:UIViewContentModeScaleAspectFit];
}

-(NSData*)writeMetadataIntoImageData:(NSData *)imageData metadata:(NSDictionary*)metadata
{
    // NOP if metadata == nil
    if (!metadata) return imageData;
    
    // Create an imagesourceref
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    if (!source) {
#if defined(DEBUG)
        NSLog(@"Error: Could not create source");
#endif
    } else {
        // Type of image (e.g., public.jpeg)
        CFStringRef UTI = CGImageSourceGetType(source);
        
        // Create a new data object and write the new image into it
        NSMutableData *dest_data = [NSMutableData data];
        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);
        if (!destination) {
#if defined(DEBUG)
            NSLog(@"Error: Could not create image destination");
#endif
            CFRelease(source);
        } else {
            // add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
            CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
            BOOL success = NO;
            success = CGImageDestinationFinalize(destination);
            if (!success) {
#if defined(DEBUG)
                NSLog(@"Error: Could not create data from image destination");
#endif
                CFRelease(destination);
                CFRelease(source);
            } else {
                CFRelease(destination);
                CFRelease(source);
                return dest_data;
            }
        }
    }
    return imageData;
}

@end
