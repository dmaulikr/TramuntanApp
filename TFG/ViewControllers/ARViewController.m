//
//  AugmentedRealityViewController.m
//  TFG
//
//  Created by Tovkal on 19/07/14.
//  Copyright (c) 2014 Tovkal. All rights reserved.
//

#import "ARViewController.h"
#import "TargetShape.h"
#import "ARView.h"

@interface ARViewController ()
@property (strong, nonatomic) ARView *myView;

@property (strong, nonatomic) ARCoreLocationController *clController;

//TODO temporary
@property (weak, nonatomic) CAShapeLayer *targetLayer;

@end

@implementation ARViewController

- (void)viewDidLoad
{
	self.myView = [[ARView alloc] initWithFrame:self.view.frame];
	self.view = self.myView;	
	
		
	[self setupDelegates];
}

- (void)viewWillAppear:(BOOL)animated
{
	//When the view is setup, draw target because if we do it before and the view starts in landscape the target will not be drawn properly as view.bounds are not correct yet
	[self drawTarget];
}

- (void) setupDelegates
{
	self.clController = [[ARCoreLocationController alloc] init];
	self.clController.delegate = self;
	[self.clController setup];
}

#pragma mark - ARDelegate

- (NSMutableArray *)poiData
{
	NSMutableArray *data = [[NSMutableArray alloc] init];
	
	return data;
}

#pragma mark - ARCLDelegate

- (void)didFindLocation:(CLLocation *)location
{
	if (self.locationDebug){
		NSLog(@"%@", location);
	}
}

#pragma mark - Target view TEMPORARY
//TODO Find better location for this
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self drawTarget];
}

- (void)drawTarget
{
	[self removeTarget];
	
	CGRect bounds = self.view.bounds;
    CGPoint center = CGPointMake((bounds.size.width/(2+bounds.origin.x)), (bounds.size.height/(2+bounds.origin.y)));
    CAShapeLayer *targetLayer = [TargetShape createTargetView:center];
    
    self.targetLayer = targetLayer;
    
    [self.view.layer addSublayer:targetLayer];
}

- (void)removeTarget
{
	if (self.targetLayer != nil) {
		[self.targetLayer removeFromSuperlayer];
	}
}

@end