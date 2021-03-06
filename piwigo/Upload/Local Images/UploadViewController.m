//
//  UploadViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "UploadViewController.h"
#import "ImageUploadManager.h"
#import "PhotosFetch.h"
#import "LocalImageCollectionViewCell.h"
#import "ImageDetailViewController.h"
#import "CategoriesData.h"
#import "ImageUpload.h"
#import "ImageUploadProgressView.h"
#import "ImageUploadViewController.h"
#import "SortHeaderCollectionReusableView.h"
#import "SortSelectViewController.h"
#import "LoadingView.h"
#import "UICountingLabel.h"
#import "ImagesCollection.h"

@interface UploadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, ImageUploadProgressDelegate, SortSelectViewControllerDelegate>

@property (nonatomic, strong) UICollectionView *localImagesCollection;
@property (nonatomic, assign) NSInteger categoryId;
@property (nonatomic, strong) NSArray *images;
@property (nonatomic, strong) PHAssetCollection *groupAsset;

@property (nonatomic, strong) UILabel *noImagesLabel;

@property (nonatomic, strong) UIBarButtonItem *selectAllBarButton;
@property (nonatomic, strong) UIBarButtonItem *cancelBarButton;
@property (nonatomic, strong) UIBarButtonItem *uploadBarButton;

@property (nonatomic, strong) NSMutableArray *selectedImages;

@property (nonatomic, assign) kPiwigoSortBy sortType;
@property (nonatomic, strong) LoadingView *loadingView;

@end

@implementation UploadViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId andGroupAsset:(PHAssetCollection*)groupAsset
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.categoryId = categoryId;
		self.groupAsset = groupAsset;
		self.title = [[[CategoriesData sharedInstance] getCategoryById:self.categoryId] name];
		
		self.images = [[PhotosFetch sharedInstance] getImagesForAssetGroup:self.groupAsset];
		self.sortType = kPiwigoSortByNewest;
		
		self.localImagesCollection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
		self.localImagesCollection.translatesAutoresizingMaskIntoConstraints = NO;
		self.localImagesCollection.backgroundColor = [UIColor clearColor];
		self.localImagesCollection.dataSource = self;
		self.localImagesCollection.delegate = self;
		[self.localImagesCollection registerClass:[LocalImageCollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
		[self.localImagesCollection registerClass:[SortHeaderCollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
		self.localImagesCollection.indicatorStyle = UIScrollViewIndicatorStyleDefault;
		[self.view addSubview:self.localImagesCollection];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.localImagesCollection]];
		
		self.noImagesLabel = [UILabel new];
		self.noImagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.noImagesLabel.font = [UIFont piwigoFontNormal];
		self.noImagesLabel.font = [self.noImagesLabel.font fontWithSize:20];
		self.noImagesLabel.textColor = [UIColor piwigoGrayLight];
		self.noImagesLabel.text = NSLocalizedString(@"noImages", @"No Images");
		self.noImagesLabel.hidden = YES;
		[self.view addSubview:self.noImagesLabel];
		[self.view addConstraint:[NSLayoutConstraint constraintViewFromTop:self.noImagesLabel amount:60]];
		[self.view addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.noImagesLabel]];
		
		self.selectedImages = [NSMutableArray new];
		
		self.selectAllBarButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"selectAll", @"All") style:UIBarButtonItemStylePlain target:self action:@selector(selectAll)];
		self.cancelBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelSelect)];
		self.uploadBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"upload"]
																style:UIBarButtonItemStylePlain
															   target:self
															   action:@selector(uploadSelected)];
	}
	return self;
}

-(void)viewDidLoad
{
	[super viewDidLoad];
	
	if([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
	{
		[self setEdgesForExtendedLayout:UIRectEdgeNone];
	}
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self loadNavButtons];
	[ImageUploadProgressView sharedInstance].delegate = self;
	
	if([ImageUploadManager sharedInstance].imageUploadQueue.count > 0)
	{
		[[ImageUploadProgressView sharedInstance] addViewToView:self.view forBottomLayout:self.bottomLayoutGuide];
	}
	
	self.sortType = self.sortType;
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.localImagesCollection reloadData];
        [self.localImagesCollection reloadSections:[NSIndexSet indexSetWithIndex:0]];
    } completion:nil];
}

-(void)loadNavButtons
{
	if(self.selectedImages.count > 0)
	{
		self.navigationItem.rightBarButtonItems = @[self.cancelBarButton, self.uploadBarButton];
	}
	else
	{
		self.navigationItem.rightBarButtonItems = @[self.selectAllBarButton];
	}
}

-(void)setSortType:(kPiwigoSortBy)sortType
{
	if(sortType != kPiwigoSortByNotUploaded && _sortType == kPiwigoSortByNotUploaded)
	{
		self.images = [[PhotosFetch sharedInstance] getImagesForAssetGroup:self.groupAsset];
	}
	
	_sortType = sortType;
	
	PiwigoAlbumData *downloadingCategory = [[CategoriesData sharedInstance] getCategoryById:self.categoryId];
	
	if(sortType == kPiwigoSortByNotUploaded)
	{
		if(!self.loadingView.superview)
		{
			self.loadingView = [LoadingView new];
			self.loadingView.translatesAutoresizingMaskIntoConstraints = NO;
			NSString *progressLabelFormat = [NSString stringWithFormat:@"%@ / %@", @"%d", @(downloadingCategory.numberOfImages)];
			self.loadingView.progressLabel.format = progressLabelFormat;
			self.loadingView.progressLabel.method = UILabelCountingMethodLinear;
			[self.loadingView showLoadingWithLabel:NSLocalizedString(@"downloadingImageInfo", @"Downloading Image Info") andProgressLabel:[NSString stringWithFormat:progressLabelFormat, 0]];
			[self.view addSubview:self.loadingView];
			[self.view addConstraints:[NSLayoutConstraint constraintCenterView:self.loadingView]];
			self.loadingView.hidden = YES;
			
			if(downloadingCategory.numberOfImages != downloadingCategory.imageList.count)
			{
				self.loadingView.hidden = NO;
				if(downloadingCategory.numberOfImages >= 100)
				{
					[self.loadingView.progressLabel countFrom:0 to:100 withDuration:1];
				}
				else
				{
					[self.loadingView.progressLabel countFrom:0 to:downloadingCategory.numberOfImages withDuration:1];
				}
			}
		}
	}
	
	
	__block NSDate *lastTime = [NSDate date];
	
	[SortSelectViewController getSortedImageArrayFromSortType:sortType
													forImages:self.images
												  forCategory:self.categoryId
												  forProgress:^(NSInteger onPage, NSInteger outOf) {
													  NSInteger lastImageCount = (onPage + 1) * [Model sharedInstance].imagesPerPage;
													  NSInteger currentDownloaded = (onPage + 2) * [Model sharedInstance].imagesPerPage;
													  
													  NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:lastTime];
													  
													  if(currentDownloaded > downloadingCategory.numberOfImages)
													  {
														  currentDownloaded = downloadingCategory.numberOfImages;
													  }
													  
													  [self.loadingView.progressLabel countFrom:lastImageCount to:currentDownloaded withDuration:duration];
													  
													  lastTime = [NSDate date];
												  } onCompletion:^(NSArray *images) {
													  
													 if(sortType == kPiwigoSortByNotUploaded && !self.loadingView.hidden)
													 {
														 [self.loadingView hideLoadingWithLabel:NSLocalizedString(@"Complete", nil) showCheckMark:YES withDelay:0.5];
													 }
													 self.images = images;
													 [self.localImagesCollection reloadData];
												  }];
}

-(void)selectAll
{
	self.selectedImages = [self.images mutableCopy];
	[self loadNavButtons];
	[self.localImagesCollection reloadData];
}

-(void)cancelSelect
{
	for(PHAsset *selectedImageAsset in self.selectedImages)
	{
		NSInteger row = [self.images indexOfObject:selectedImageAsset];
		if(row != NSNotFound)
		{
			LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
			cell.cellSelected = NO;
		}
	}
	self.selectedImages = [NSMutableArray new];
	[self loadNavButtons];
}

-(void)uploadSelected
{
	[self showImageUpload];
}

-(void)showImageUpload
{
	ImageUploadViewController *vc = [ImageUploadViewController new];
	vc.selectedCategory = self.categoryId;
	vc.imagesSelected = self.selectedImages;
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
	[self.navigationController presentViewController:nav animated:YES completion:nil];
	self.selectedImages = [NSMutableArray new];
}

#pragma mark UICollectionView Methods

-(UICollectionReusableView*)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
	SortHeaderCollectionReusableView *header = nil;
	
	if(kind == UICollectionElementKindSectionHeader)
	{
		header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header" forIndexPath:indexPath];
		header.currentSortLabel.text = [SortSelectViewController getNameForSortType:self.sortType];
		[header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didSelectCollectionViewHeader)]];
	}
	
	return header;
}

-(void)didSelectCollectionViewHeader
{
	SortSelectViewController *sortSelectVC = [SortSelectViewController new];
	sortSelectVC.delegate = self;
	sortSelectVC.currentSortType = self.sortType;
	[self.navigationController pushViewController:sortSelectVC animated:YES];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
	return CGSizeMake(collectionView.frame.size.width, 44.0);
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	self.noImagesLabel.hidden = self.images.count != 0;

	return self.images.count;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(10, kMarginsSpacing, 40, kMarginsSpacing);
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kCellSpacing;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kCellSpacing;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Calculate the optimum image size
    CGFloat size = (CGFloat)[ImagesCollection imageSizeForCollectionView:collectionView];

    return CGSizeMake(size, size);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	LocalImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
	
	PHAsset *imageAsset = [self.images objectAtIndex:indexPath.row];
    [cell setupWithImageAsset:imageAsset andThumbnailSize:(CGFloat)[ImagesCollection imageSizeForCollectionView:collectionView]];
	
    // For some unknown reason, the asset resource may be empty
    NSArray *resources = [PHAssetResource assetResourcesForAsset:imageAsset];
    NSString *originalFilename;
    if ([resources count] > 0) {
        originalFilename = ((PHAssetResource*)resources[0]).originalFilename;
    } else {
        // No filename => Build filename from 32 characters of local identifier
        NSRange range = [imageAsset.localIdentifier rangeOfString:@"/"];
        originalFilename = [[imageAsset.localIdentifier substringToIndex:range.location] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    }    
    if([self.selectedImages containsObject:imageAsset])
	{
		cell.cellSelected = YES;
	}
    else if ([[ImageUploadManager sharedInstance].imageNamesUploadQueue objectForKey:[originalFilename stringByDeletingPathExtension]])
    {
        cell.cellUploading = YES;
    }

    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	LocalImageCollectionViewCell *selectedCell = (LocalImageCollectionViewCell*)[collectionView cellForItemAtIndexPath:indexPath];
	
	PHAsset *imageAsset = [self.images objectAtIndex:indexPath.row];
	
	if(selectedCell.cellSelected)
	{	// The cell is selected, remove it
		[self.selectedImages removeObject:imageAsset];
		selectedCell.cellSelected = NO;
	}
	else
	{	// Select the cell
		[self.selectedImages addObject:imageAsset];
		selectedCell.cellSelected = YES;
	}
	
	[self loadNavButtons];
}

#pragma mark ImageUploadProgressDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks iCloudProgress:(CGFloat)iCloudProgress
{
    NSInteger row = [self.images indexOfObject:image.imageAsset];
    LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];

    CGFloat chunkPercent = 100.0 / totalChunks / 100.0;
    CGFloat onChunkPercent = chunkPercent * (currentChunk - 1);
    CGFloat pieceProgress = (CGFloat)current / total;
    CGFloat uploadProgress = onChunkPercent + (chunkPercent * pieceProgress);
    if(uploadProgress > 1)
    {
        uploadProgress = 1;
    }

    if (iCloudProgress < 0) {
        cell.progress = uploadProgress;
//        NSLog(@"UploadViewController[ImageProgress]: %.2f", uploadProgress);
    } else {
        cell.progress = (iCloudProgress + uploadProgress) / 2.0;
//    NSLog(@"UploadViewController[ImageProgress]: %.2f", ((iCloudProgress + uploadProgress) / 2.0));
    }
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
//    NSLog(@"UploadViewController[imageUploaded]");
    NSInteger row = [self.images indexOfObject:image.imageAsset];
	LocalImageCollectionViewCell *cell = (LocalImageCollectionViewCell*)[self.localImagesCollection cellForItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
	cell.cellUploading = NO;
	
    // Update list of "Not Uploaded" images
	if(self.sortType == kPiwigoSortByNotUploaded)
	{
		NSMutableArray *newList = [self.images mutableCopy];
		[newList removeObject:image.imageAsset];
		self.images = newList;

        // Update image collection
        [self.localImagesCollection reloadData];
	}
}


#pragma mark SortSelectViewControllerDelegate Methods

-(void)didSelectSortTypeOf:(kPiwigoSortBy)sortType
{
	self.sortType = sortType;
}

@end
