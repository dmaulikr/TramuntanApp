//
//  ARView.m
//  AR-Framework
//
//  Created by Tovkal on 23/07/14.
//  Copyright (c) 2014 Tovkal. All rights reserved.
//

#import "ARView.h"
#import "Mountain.h"
#import "ARUtils.h"
#import <GLKit/GLKit.h>
#import "UIDeviceHardware.h"
#import "TramuntanApp-Swift.h"
#import "Constants.h"
#import "Store.h"
#import <Crashlytics/Crashlytics.h>

@interface ARView()
{
    mat4f_t projectionTransform;
    mat4f_t cameraTransform;
}

@property (strong, nonatomic) UIView *captureView;

@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDevice *videoDeviceInput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureLayer;

@property (strong, nonatomic) CADisplayLink *displayLink;

@property (nonatomic) double horizontalFOV;
@property (nonatomic) double verticalFOV;

@property (nonatomic) BOOL fovIsSaved;

@end

@implementation ARView

#pragma mark - Inits

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
    
    self.mountainContainer = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:self.mountainContainer];
    
    self.displayMountains = NO;
}

- (void)start
{
    AVCaptureDevice *inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *deviceInputError = nil;
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:&deviceInputError];
    self.videoDeviceInput = inputDevice;
    
    if (!captureInput || deviceInputError != nil) {
        [CrashlyticsKit recordError:[NSError errorWithDomain:@"AR View setup" code:2 userInfo:@{NSLocalizedDescriptionKey: @"captureInput or deviceInputError are null", NSUnderlyingErrorKey: deviceInputError}]];
    }
    
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    NSString *key = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    NSNumber *value = [NSNumber numberWithUnsignedInteger:kCVPixelFormatType_32BGRA];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    
    [captureOutput setVideoSettings:videoSettings];
    
    self.captureSession = [[AVCaptureSession alloc] init];
    
    NSString *preset = 0;
    
    if (!preset) {
        preset = AVCaptureSessionPresetHigh;
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
    
    [self startDisplayLink];
    
    [self setFOV];
    // Initialize projection matrix
    [self createProjectionMatrixWithCurrentOrientation:[[UIDevice currentDevice] orientation]];
}

- (void)stop
{
    [self.captureLayer removeFromSuperlayer];
    self.captureLayer = nil;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.captureSession stopRunning];
    });
    
    self.captureSession = nil;
    [self stopDisplayLink];
}

#pragma mark Display link

- (void)startDisplayLink
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLink:)];
    [self.displayLink setFrameInterval:1];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)stopDisplayLink
{
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)onDisplayLink:(id)sender
{
    CMAttitude *a = [self.delegate performSelector:@selector(fetchAttitude)];
    if (a != nil) {
        CMRotationMatrix r = a.rotationMatrix;
        
        //Landscape support from: http://stackoverflow.com/a/15457305/1283228
        UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
        float deviceOrientationRadians = 0.0f;
        if (orientation == UIDeviceOrientationLandscapeLeft) {
            deviceOrientationRadians = (float) M_PI_2;
        } else if (orientation == UIDeviceOrientationLandscapeRight) {
            deviceOrientationRadians = (float) -M_PI_2;
        }
        
        [self createProjectionMatrixWithCurrentOrientation:orientation];
        
        GLKMatrix4 baseRotation = GLKMatrix4MakeRotation(deviceOrientationRadians, 0.0f, 0.0f, 1.0f);
        GLKMatrix4 deviceMotionAttitudeMatrix = GLKMatrix4Make((float) r.m11, (float) r.m21, (float) r.m31, 0.0f,
                                                               (float) r.m12, (float) r.m22, (float) r.m32, 0.0f,
                                                               (float) r.m13, (float) r.m23, (float) r.m33, 0.0f,
                                                               0.0f, 0.0f, 0.0f, 1.0f);
        deviceMotionAttitudeMatrix = GLKMatrix4Multiply(baseRotation, deviceMotionAttitudeMatrix);
        
        cameraTransform[0] = deviceMotionAttitudeMatrix.m00;
        cameraTransform[1] = deviceMotionAttitudeMatrix.m01;
        cameraTransform[2] = deviceMotionAttitudeMatrix.m02;
        cameraTransform[3] = deviceMotionAttitudeMatrix.m03;
        
        cameraTransform[4] = deviceMotionAttitudeMatrix.m10;
        cameraTransform[5] = deviceMotionAttitudeMatrix.m11;
        cameraTransform[6] = deviceMotionAttitudeMatrix.m12;
        cameraTransform[7] = deviceMotionAttitudeMatrix.m13;
        
        cameraTransform[8] = deviceMotionAttitudeMatrix.m20;
        cameraTransform[9] = deviceMotionAttitudeMatrix.m21;
        cameraTransform[10] = deviceMotionAttitudeMatrix.m22;
        cameraTransform[11] = deviceMotionAttitudeMatrix.m23;
        
        cameraTransform[12] = deviceMotionAttitudeMatrix.m30;
        cameraTransform[13] = deviceMotionAttitudeMatrix.m31;
        cameraTransform[14] = deviceMotionAttitudeMatrix.m32;
        cameraTransform[15] = deviceMotionAttitudeMatrix.m33;
        
        [self setNeedsDisplay];
    }
}

- (void)createProjectionMatrixWithCurrentOrientation:(UIDeviceOrientation)orientation
{
    if (orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight) {
        createProjectionMatrix(projectionTransform, (float) (self.verticalFOV * DEGREES_TO_RADIANS), (float) (self.bounds.size.width / self.bounds.size.height), 0.25f, 1000.0f);
    } else if (orientation == UIDeviceOrientationPortrait) {
        createProjectionMatrix(projectionTransform, (float) (self.horizontalFOV * DEGREES_TO_RADIANS), (float) (self.bounds.size.width / self.bounds.size.height), 0.25f, 1000.0f);
    }
}

- (void)setFOV
{
    // If available, use the format's FOV and calculate the vertical
    if (self.videoDeviceInput != nil && self.videoDeviceInput.activeFormat.videoFieldOfView != 0) {
        
        self.horizontalFOV = self.videoDeviceInput.activeFormat.videoFieldOfView;
        self.verticalFOV = self.horizontalFOV * (self.captureView.frame.size.width / self.captureView.frame.size.height);
        
        return;
    }
    
    //Fov angle from: http://stackoverflow.com/a/3594424/1283228
    NSString *device = [UIDeviceHardware platformStringSimple];
    if ([device isEqualToString:@"iPhone 4"]) {
        self.horizontalFOV = 60.8;
        self.verticalFOV = 47.5;
    } else if ([device isEqualToString:@"iPhone 4S"]) {
        self.horizontalFOV = 55.7;
        self.verticalFOV = 43.2;
    } else if ([device isEqualToString:@"iPhone 5"]) { //Not sure
        self.horizontalFOV = 56.700;
        self.verticalFOV = 48.0;
    } else if([device isEqualToString:@"iPhone 5c"]) { //Not sure
        self.horizontalFOV = 61.4;
        self.verticalFOV = 48.0;
    } else if ([device isEqualToString:@"iPhone 5s"]) {
        self.horizontalFOV = 58.080002;
        self.verticalFOV = 31;//40.7;//48.0;
    } else if ([device isEqualToString:@"iPhone 5s"]) {
        self.horizontalFOV = 58.080002;
        self.verticalFOV = 32;
    } else if ([device isEqualToString:@"iPhone 6"]) {
        self.horizontalFOV = 71.4532002;
        self.verticalFOV = 59.1472102;
    } else if ([device isEqualToString:@"iPhone 6+"]) {
        self.horizontalFOV = 72.6272908;
        self.verticalFOV = 60.0827279;
    }
}

#pragma mark - View
- (void)orientationChanged:(NSNotification *)notification
{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    
    if (self.captureLayer) {
        switch (orientation) {
            case UIDeviceOrientationLandscapeLeft:
                [self.captureLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
                break;
            case UIDeviceOrientationPortrait:
                [self.captureLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
                break;
            case UIDeviceOrientationLandscapeRight:
                [self.captureLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
                break;
            default:
                break;
        }
    }
    
    self.captureLayer.frame = self.bounds;
}

- (void)drawRect:(CGRect)rect
{
    if (pointsOfInterestCoordinates == nil || !self.displayMountains) {
        return;
    }
    
    mat4f_t projectionCameraTransform;
    multiplyMatrixAndMatrix(projectionCameraTransform, projectionTransform, cameraTransform);
    
    int i = 0;
    for (Mountain *poi in [[[Store sharedInstance] getPointsOfInterest] objectEnumerator]) {
        
        if ([[Utils sharedInstance] getRadiusInMeters] > poi.distance) {
            
            vec4f_t v;
            
            multiplyMatrixAndVector(v, projectionCameraTransform, pointsOfInterestCoordinates[i]);
            
            float x = (v[0] / v[3] + 1.0f) * 0.5f;
            float y = (v[1] / v[3] + 1.0f) * 0.5f;
            if (v[2] < 0.0f) {
                poi.view.center = CGPointMake(x*self.bounds.size.width, self.bounds.size.height-y*self.bounds.size.height);
                poi.view.hidden = NO;
            } else {
                poi.view.hidden = YES;
            }
        } else {
            //POI outside of radius
            poi.view.hidden = YES;
        }
        i++;
    }
    
    //TODO Podria crear una classe per gestionar lo de controlar quan una muntanya entra dings Target, i aquí fer un set de ses subviews
    //o algo per evitar fer-ho cada vegada allà on esta ara amb dispatch tal.
}

@end
