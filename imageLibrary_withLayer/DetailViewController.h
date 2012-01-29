//
//  DetailViewController.h
//  imageLibrary_withLayer
//
//  Created by Leonov Valentin on 1/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface DetailViewController : UIViewController <UIScrollViewDelegate, NSCacheDelegate>

@property (retain, nonatomic) NSMutableArray *imageLayerArray;
@property (retain, nonatomic) NSMutableArray *thumbnailArray;
@property (retain, nonatomic) NSArray *imageNameArray;
@property (retain, nonatomic) IBOutlet UIScrollView *scrollView;

@property (retain, nonatomic) CALayer *leftLayer;
@property (retain, nonatomic) CALayer *currentLayer;
@property (retain, nonatomic) CALayer *rightLayer;

- (void) showImageLayersWithCurrentLayerNumber: (NSInteger)number;

@end
