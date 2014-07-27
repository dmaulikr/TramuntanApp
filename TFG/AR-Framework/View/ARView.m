//
//  ARView.m
//  AR-Framework
//
//  Created by Tovkal on 23/07/14.
//  Copyright (c) 2014 Tovkal. All rights reserved.
//

#import "ARView.h"
#import "TargetShape.h"

@interface ARView()

@property (strong, nonatomic) UIView *captureView;

@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDevice *videoDeviceInput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureLayer;
@end

@implementation ARView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		[self initialize];
    }
    return self;
}

- (void)initialize
{
	self.captureView = [[UIView alloc] initWithFrame:self.bounds];
	self.captureView.bounds = self.bounds;
	[self addSubview:self.captureView];
	[self sendSubviewToBack:self.captureView];
}

- (void)start
{
	AVCaptureDevice *inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	NSError *deviceInputError = nil;
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:&deviceInputError];
	self.videoDeviceInput = inputDevice;
	
	if (!captureInput || deviceInputError != nil) {
		NSLog(@"Error during init of AVView");
	}
	
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	
	NSString *key = (NSString *)kCVPixelBufferPixelFormatTypeKey;
	NSNumber *value = [NSNumber numberWithUnsignedInteger:kCVPixelFormatType_32BGRA];
	NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
	
	[captureOutput setVideoSettings:videoSettings];
	
	self.captureSession = [[AVCaptureSession alloc] init];
    
    NSString *preset = 0;
    
    if (!preset) {
        preset = AVCaptureSessionPresetMedium;
    }
    
    self.captureSession.sessionPreset = preset;
    
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
    //handle prevLayer
    if (!self.captureLayer) {
        self.captureLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    
    //if you want to adjust the previewlayer frame, here!
	self.captureLayer.frame = self.captureView.bounds;
    self.captureLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.captureView.layer addSublayer: self.captureLayer];
    
	// Start the session. This is done asychronously since -startRunning doesn't return until the session is running.
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[self.captureSession startRunning];
	});
	
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:@"UIDeviceOrientationDidChangeNotification" object:nil];
	
	//If view starts in landscape, rotate the AV view.
	if ([[UIDevice currentDevice] orientation] != UIDeviceOrientationPortrait) {
		[self orientationChanged:nil];
	}
}

- (void)stop
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[self.captureSession stopRunning];
	});
	[self.captureLayer removeFromSuperlayer];
	self.captureSession = nil;
	self.captureLayer = nil;
}

- (void)orientationChanged:(NSNotification *)notification
{
	CGRect bounds = CGRectMake(0, 0, 1, 1);
    
    int xInt = 0;
    int yInt = 0;
	
	CGSize screenSize = [[UIScreen mainScreen] bounds].size;
	
	xInt = screenSize.width;
	yInt = screenSize.height;
	
    //TODO Test if it works on iPad. I think there's no need to hardcode the screen sizes.
	
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
//        //its iphone
//        CGSize result = [[UIScreen mainScreen] bounds].size;
//        if(result.height == 480) {
//            // iPhone Classic
//            xInt = 320;
//            yInt = 480;
//        }
//        else if(result.height == 568) {
//            // iPhone 5
//            xInt = 320;
//            yInt = 568;
//        }
//    } else {
//        //its ipad
//        xInt = 768;
//        yInt = 1024;
//    }
    
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    
    BOOL rotate = YES;
    
    switch (orientation) {
        case UIDeviceOrientationLandscapeLeft:
            bounds = CGRectMake(0, 0, yInt, xInt);
            self.captureLayer.affineTransform = CGAffineTransformMakeRotation(M_PI + M_PI_2); // 270 degress
            break;
        case UIDeviceOrientationLandscapeRight:
            bounds = CGRectMake(0, 0, yInt, xInt);
            self.captureLayer.affineTransform = CGAffineTransformMakeRotation(M_PI_2); // 90 degrees
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            rotate = NO;
            //bounds = CGRectMake(0, 0, xInt, yInt);
            //self.captureVideoPreviewLayer.affineTransform = CGAffineTransformMakeRotation(M_PI); // 180 degrees
            break;
		case UIDeviceOrientationFaceDown:
		case UIDeviceOrientationFaceUp:
			rotate = NO;
			break;
        default: //Portrait
            bounds = CGRectMake(0, 0, xInt, yInt);
            self.captureLayer.affineTransform = CGAffineTransformMakeRotation(0.0);
            break;
    }
    
    if (rotate) {
        self.captureLayer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    }
}

@end