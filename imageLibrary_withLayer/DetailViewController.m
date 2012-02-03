//
//  DetailViewController.m
//  imageLibrary_withLayer
//
//  Created by Leonov Valentin on 1/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController()

- (void) scrollRightToLeftWithCurrentLayerNumber:(NSInteger) currentLayerNumber;
- (void) scrollLeftToRightWithCurrentLayerNumber:(NSInteger) currentLayerNumber;

- (void) addCurrentLayerWithGlabalNumber:(NSInteger) number;
- (void) addLeftLayerWithGlabalNumber:(NSInteger) number;
- (void) addRightLayerWithGlabalNumber:(NSInteger) number;
- (void) asyncLoadLayersWithCurrentLayerNumber:(NSInteger)number leftLayer:(CALayer *)leftLayer currentLayer:(CALayer *)currentLayer rightLayer:(CALayer *)rightLayer;
- (UIImage *) resizeImageNumber:(NSInteger) number;

- (void) handleDoubleTap;

@end

@implementation DetailViewController
{
    NSMutableArray *_imageLayerArray;
    
    CALayer *_leftLayer;
    CALayer *_currentLayer;
    CALayer *_rightLayer;
    
    NSInteger _leftImageCount;
    NSInteger _rightImageCount;
    
    BOOL _fromMainPage;
    
    __block NSCache *_imageCache;
    
    UITapGestureRecognizer *_doubleTap;
}

CGFloat const SCALE_COEFFICIENT = 0.5;
CGFloat const IMAGE_WIDTH = 320*SCALE_COEFFICIENT;
CGFloat const IMAGE_HEIGHT = 480*SCALE_COEFFICIENT;
CGFloat const BORDER_WIDTH = 2;
CGFloat const NEXT_IMAGE_OFFSET = 7;
CGFloat CURRENT_LAYER_Z_OFFSET_1 = IMAGE_WIDTH / 3;
CGFloat CURRENT_LAYER_Z_OFFSET_2 = IMAGE_WIDTH / 1.25;
CGFloat const GROUP_IMAGE_SIZE = 36;
CGFloat const ROTATION_ANGLE = M_PI / 6;

@synthesize imageLayerArray = _imageLayerArray;
@synthesize thumbnailArray = _thumbnailArray;
@synthesize imageNameArray = _imageNameArray;
@synthesize scrollView = _scrollView;

@synthesize leftLayer = _leftLayer, currentLayer = _currentLayer, rightLayer = _rightLayer;

- (void) setThumbnailArray:(NSMutableArray *)thumbnailArray
{
    [thumbnailArray retain];
    [_thumbnailArray release];
    _thumbnailArray = thumbnailArray;
    _imageLayerArray = [[NSMutableArray alloc] initWithCapacity:self.thumbnailArray.count];
    for (NSInteger i=0; i<self.thumbnailArray.count; i++) {
        CALayer *layer = [[[CALayer alloc] init] autorelease];
        [_imageLayerArray addObject:layer];
    }

    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width * self.thumbnailArray.count, self.view.bounds.size.height);
    [thumbnailArray release];
}

- (void)dealloc
{
    [_imageLayerArray release], _imageLayerArray = nil;
    self.thumbnailArray = nil;
    self.imageNameArray = nil;
    self.scrollView = nil;
    self.leftLayer = nil;
    self.currentLayer = nil;
    self.rightLayer = nil;
    [_imageCache release], _imageCache = nil;
    [_doubleTap release], _doubleTap = nil;
    [super dealloc];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_fromMainPage == YES) {
        _fromMainPage = NO;
        return;
    }
    
    CGFloat pageWidth = scrollView.frame.size.width;
    float fractionalPage = scrollView.contentOffset.x / pageWidth;
    NSInteger page = lround(fractionalPage);
    NSInteger currentLayerNumber = [_imageLayerArray indexOfObject:self.currentLayer];
    
    if (currentLayerNumber < page) { // Листаем справа налево
        [self scrollRightToLeftWithCurrentLayerNumber:currentLayerNumber];
    }
    else if ([_imageLayerArray indexOfObject:self.currentLayer] > page) { // Листаем слева направо
        [self scrollLeftToRightWithCurrentLayerNumber:currentLayerNumber];
    }
}

- (void) scrollRightToLeftWithCurrentLayerNumber:(NSInteger) currentLayerNumber
{
    // debug
    NSLog(@"1: %d, %d, %d", [self.imageLayerArray indexOfObject:self.leftLayer], [self.imageLayerArray indexOfObject:self.currentLayer], [self.imageLayerArray indexOfObject:self.rightLayer]);
    
    // Offset of layers before current
    for (NSInteger i=0; i<currentLayerNumber; i++) {
        CALayer *layer = [_imageLayerArray objectAtIndex:i];
        layer.position = CGPointMake(IMAGE_WIDTH/2 + GROUP_IMAGE_SIZE/(_leftImageCount+1)*i, layer.position.y);
    }
    
    // Current layer offset
    CALayer *layer = [_imageLayerArray objectAtIndex:currentLayerNumber];
    
    layer.zPosition = 0;
    if (_leftImageCount != 0)
    {
        layer.position = CGPointMake(self.leftLayer.position.x + GROUP_IMAGE_SIZE/(_leftImageCount+1), layer.position.y);
    }
    else
    {
        layer.position = CGPointMake(IMAGE_WIDTH/2, layer.position.y);
    }
    layer.transform = CATransform3DRotate(CATransform3DIdentity, ROTATION_ANGLE, 0, 1, 0);
    _leftImageCount++;
    
    // Offset of layers after right layer
    for (NSInteger i=currentLayerNumber+1; i<_imageLayerArray.count; i++) {
        CALayer *layer = [_imageLayerArray objectAtIndex:i];
        if (_rightImageCount > 1)
        {
            layer.position = CGPointMake(self.view.bounds.size.width - IMAGE_WIDTH/2 - GROUP_IMAGE_SIZE/(_rightImageCount-1)*(_imageLayerArray.count-i-1), layer.position.y);
        }
    }
    
    // Right layer offset
    self.leftLayer = self.currentLayer;
    self.currentLayer = self.rightLayer;
    if (_rightImageCount == 1) {
        self.rightLayer = nil;
    }
    else
    {
//        self.rightLayer = [_imageLayerArray objectAtIndex:[_imageLayerArray indexOfObject:self.currentLayer]+1];
        self.rightLayer = [_imageLayerArray objectAtIndex:currentLayerNumber+2];
        
        CALayer *rightLayer = self.rightLayer;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void){
            UIImage *thumbnail = [self resizeImageNumber:currentLayerNumber + 2];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                rightLayer.contents = (id)[thumbnail CGImage];
            });
        });
    }
    _rightImageCount--;
    layer = self.currentLayer;
    layer.transform = CATransform3DIdentity;        
    layer.frame = CGRectMake(0, 0, IMAGE_WIDTH, IMAGE_HEIGHT);
    layer.zPosition = CURRENT_LAYER_Z_OFFSET_1;
    layer.position = self.view.center;
    
    // debug
    NSLog(@"2: %d, %d, %d", [self.imageLayerArray indexOfObject:self.leftLayer], [self.imageLayerArray indexOfObject:self.currentLayer], [self.imageLayerArray indexOfObject:self.rightLayer]);
}

- (void) scrollLeftToRightWithCurrentLayerNumber:(NSInteger) currentLayerNumber
{
    // Offset of layers after right layer
    for (NSInteger i=currentLayerNumber+1; i<_imageLayerArray.count; i++) {
        CALayer *layer = [_imageLayerArray objectAtIndex:i];
        layer.position = CGPointMake(self.view.bounds.size.width - IMAGE_WIDTH/2 - GROUP_IMAGE_SIZE/(_rightImageCount+1)*(_imageLayerArray.count-i-1), layer.position.y);
    }
    
    // Current layer offset
    CALayer *layer = self.currentLayer;
    
    layer.zPosition = 0;
    if (_rightImageCount != 0)
    {
        layer.position = CGPointMake(self.rightLayer.position.x - GROUP_IMAGE_SIZE/(_rightImageCount+1), layer.position.y);
    }
    else
    {
        layer.position = CGPointMake(self.view.bounds.size.width - IMAGE_WIDTH/2, layer.position.y);
    }
    
    layer.transform = CATransform3DRotate(CATransform3DIdentity, -ROTATION_ANGLE, 0, 1, 0);
    _rightImageCount++;
    
    // Offset of layers before current
    for (NSInteger i=0; i<currentLayerNumber; i++) {
        CALayer *layer = [_imageLayerArray objectAtIndex:i];
        if (_leftImageCount > 1)
        {
            layer.position = CGPointMake(IMAGE_WIDTH/2 + GROUP_IMAGE_SIZE/(_leftImageCount-1)*i, layer.position.y);
        }
    }
    
    // Left layer offset
    self.rightLayer = self.currentLayer;
    self.currentLayer = self.leftLayer;
    
    if (_leftImageCount == 1) {
        self.leftLayer = nil;
    }
    else
    {
        self.leftLayer = [_imageLayerArray objectAtIndex:[_imageLayerArray indexOfObject:self.currentLayer]-1];
        
        CALayer *leftLayer = self.leftLayer;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void){
            UIImage *thumbnail = [self resizeImageNumber:currentLayerNumber - 2];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                leftLayer.contents = (id)[thumbnail CGImage];
            });
        });
    }
    _leftImageCount--;
    layer = self.currentLayer;
    layer.transform = CATransform3DIdentity;        
    layer.frame = CGRectMake(0, 0, IMAGE_WIDTH, IMAGE_HEIGHT);
    layer.zPosition = CURRENT_LAYER_Z_OFFSET_1;
    layer.position = self.view.center;
}

- (void) showImageLayersWithCurrentLayerNumber: (NSInteger)number
{
    self.scrollView.contentOffset = CGPointMake(self.scrollView.frame.size.width * number, self.scrollView.contentOffset.y);
    
    _leftImageCount = number;
    _rightImageCount = self.thumbnailArray.count - number - 1;
    
    // Load current layer
    [self addCurrentLayerWithGlabalNumber:number];
    self.currentLayer = [_imageLayerArray objectAtIndex:number];
    
    // Load left layers
    for (NSInteger i=0; i<number; i++) {
        [self addLeftLayerWithGlabalNumber:i];
    }
    
    // Load right layers
    for (NSInteger i=self.thumbnailArray.count-1; i>number; i--) {
        [self addRightLayerWithGlabalNumber:i];
    }
    
    if (number == 0) {
        self.leftLayer = nil;
        self.rightLayer = [_imageLayerArray objectAtIndex:number+1];
    }
    else if (number != _imageNameArray.count-1) {
        self.leftLayer = [_imageLayerArray objectAtIndex:number-1];
        self.rightLayer = [_imageLayerArray objectAtIndex:number+1];
        
    }
    else {
        self.leftLayer = [_imageLayerArray objectAtIndex:number-1];
        self.rightLayer = nil;
    }
    
    // Async load layers
    [self asyncLoadLayersWithCurrentLayerNumber:number leftLayer:self.leftLayer currentLayer:self.currentLayer rightLayer:self.rightLayer];

}

- (void) asyncLoadLayersWithCurrentLayerNumber:(NSInteger)number leftLayer:(CALayer *)leftLayer currentLayer:(CALayer *)currentLayer rightLayer:(CALayer *)rightLayer
{
    // Load current layer
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
        UIImage *thumbnail = [self resizeImageNumber:number];
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            currentLayer.contents = (id)[thumbnail CGImage];
        });
    });
    
    // Load left layer
    if (number > 0)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void){
            UIImage *thumbnail = [self resizeImageNumber:number-1];
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                leftLayer.contents = (id)[thumbnail CGImage];
            });
        });
    }
    else
    {
        leftLayer = nil;
    }
    
    // Load right layer
    if (number < self.imageLayerArray.count-1)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void){
            UIImage *thumbnail = [self resizeImageNumber:number+1];
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                rightLayer.contents = (id)[thumbnail CGImage];
            });
        });
    }
    else
    {
        rightLayer = nil;
    }
}

- (UIImage *) resizeImageNumber:(NSInteger) number
{
    UIImage *thumbnail  = [_imageCache objectForKey:[NSNumber numberWithInt:number]];
    
    if (!thumbnail) {
        UIImage *image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:[_imageNameArray objectAtIndex:number]
                                                                                          ofType:nil
                                                                                     inDirectory:@"Images"]];
        CGSize destinationSize = CGSizeMake(IMAGE_WIDTH / SCALE_COEFFICIENT, IMAGE_HEIGHT / SCALE_COEFFICIENT);
        
        UIGraphicsBeginImageContext(destinationSize);
        [image drawInRect:CGRectMake(0, 0, destinationSize.width, destinationSize.height)];
        thumbnail = UIGraphicsGetImageFromCurrentImageContext();
        
        [_imageCache setObject:thumbnail
                        forKey:[NSNumber numberWithInt:number]];
        
        UIGraphicsEndImageContext();
    }
    
    return thumbnail;
}

- (void) addCurrentLayerWithGlabalNumber:(NSInteger) number
{
    CALayer *layer = [[[CALayer alloc] init] autorelease];
    layer.contents = (id)[[self.thumbnailArray objectAtIndex:number] CGImage];
    layer.frame = CGRectMake(0, 0, IMAGE_WIDTH, IMAGE_HEIGHT);
    layer.zPosition = CURRENT_LAYER_Z_OFFSET_1;
    layer.position = self.view.center;
    layer.borderWidth = BORDER_WIDTH;
    layer.borderColor = [UIColor blackColor].CGColor;
    
    [[_imageLayerArray objectAtIndex:number] removeFromSuperlayer];
    [_imageLayerArray replaceObjectAtIndex:number withObject:layer];
    [self.view.layer addSublayer:layer];
}

- (void) addLeftLayerWithGlabalNumber:(NSInteger) number
{
    CALayer *layer = [[[CALayer alloc] init] autorelease];
    layer.contents = (id)[[self.thumbnailArray objectAtIndex:number] CGImage];
    layer.frame = CGRectMake(GROUP_IMAGE_SIZE/_leftImageCount*number, 0, IMAGE_WIDTH, IMAGE_HEIGHT);
    layer.transform = CATransform3DRotate(CATransform3DIdentity, ROTATION_ANGLE, 0, 1, 0);
    layer.position = CGPointMake(layer.position.x, self.view.center.y);
    layer.borderWidth = BORDER_WIDTH;
    layer.borderColor = [UIColor blackColor].CGColor;
    
    [[_imageLayerArray objectAtIndex:number] removeFromSuperlayer];
    [_imageLayerArray replaceObjectAtIndex:number withObject:layer];
    [self.view.layer addSublayer:layer];
}

- (void) addRightLayerWithGlabalNumber:(NSInteger) number
{
    CALayer *layer = [[[CALayer alloc] init] autorelease];
    layer.contents = (id)[[self.thumbnailArray objectAtIndex:number] CGImage];
    layer.frame = CGRectMake(self.view.bounds.size.width - IMAGE_WIDTH - GROUP_IMAGE_SIZE/_rightImageCount*(self.thumbnailArray.count-1) + GROUP_IMAGE_SIZE/_rightImageCount*number, 0, IMAGE_WIDTH, IMAGE_HEIGHT);
    layer.transform = CATransform3DRotate(CATransform3DIdentity, -ROTATION_ANGLE, 0, 1, 0);
    layer.position = CGPointMake(layer.position.x, self.view.center.y);
    layer.borderWidth = BORDER_WIDTH;
    layer.borderColor = [UIColor blackColor].CGColor;
    
    [[_imageLayerArray objectAtIndex:number] removeFromSuperlayer];
    [_imageLayerArray replaceObjectAtIndex:number withObject:layer];
    [self.view.layer addSublayer:layer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [self setScrollView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    _fromMainPage = YES;
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)cache:(NSCache *)cache willEvictObject:(id)obj
{
    NSInteger number = (NSInteger)obj;
    CALayer *layer = [self.imageLayerArray objectAtIndex:number];
    layer.contents = (id)[[self.thumbnailArray objectAtIndex:number] CGImage];
}

- (void) handleDoubleTap
{
    if (self.currentLayer.zPosition == CURRENT_LAYER_Z_OFFSET_1)
    {
        self.currentLayer.zPosition = CURRENT_LAYER_Z_OFFSET_2;
//        _currentLayerOnFullScreen = YES;
    }
    else
    {
        self.currentLayer.zPosition = CURRENT_LAYER_Z_OFFSET_1;
//        _currentLayerOnFullScreen = NO;
    }
    
    // Swap zOffsets
    CGFloat zOffset = CURRENT_LAYER_Z_OFFSET_1;
    CURRENT_LAYER_Z_OFFSET_1 = CURRENT_LAYER_Z_OFFSET_2;
    CURRENT_LAYER_Z_OFFSET_2 = zOffset;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    _imageCache.delegate = self;
    _fromMainPage = YES;
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Detail", @"Detail");

        CATransform3D transform = self.view.layer.transform;
        transform.m34 = 1.0 / -300.0;
        self.view.layer.sublayerTransform = transform;
        
        _imageCache = [[NSCache alloc] init];
        
        _doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                             action:@selector(handleDoubleTap)];
        _doubleTap.numberOfTapsRequired = 2;
        [self.view addGestureRecognizer:_doubleTap];
    }
    
    return self;
}
							
@end
