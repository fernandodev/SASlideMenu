//
//  SASlideMenuDynamicViewController.m
//  SASlideMenu
//
//  Created by Stefano Antonelli on 11/20/12.
//  Copyright (c) 2012 Stefano Antonelli. All rights reserved.
//

#import "SASlideMenuDynamicViewController.h"
#import <QuartzCore/QuartzCore.h>

#define kSlideInInterval 0.3
#define kSlideOutInterval 0.1
#define kVisiblePortion 40
#define kMenuTableSize 280

@interface SASlideMenuDynamicViewController (){
    UINavigationController* selectedContent;
    BOOL isFirstViewWillAppear;
}

@property (nonatomic, strong) UIView* shield;

@end

@implementation SASlideMenuDynamicViewController

@synthesize slideMenuDataSource;
@synthesize controllers;

-(void) slideOut:(UINavigationController*) controller{
    CGRect bounds = self.view.bounds;
    controller.view.frame = CGRectMake(bounds.size.width,0.0,bounds.size.width,bounds.size.height);
}

-(void) slideToSide:(UINavigationController*) controller{
    CGRect bounds = self.view.bounds;
    controller.view.frame = CGRectMake(kMenuTableSize,0.0,bounds.size.width,bounds.size.height);
}

-(void) slideIn:(UINavigationController*) controller{
    CGRect bounds = self.view.bounds;
    controller.view.frame = CGRectMake(0.0,0.0,bounds.size.width,bounds.size.height);
}

-(void) completeSlideIn:(UINavigationController*) controller{
     [self.shield removeFromSuperview];
     [controller.visibleViewController.view addSubview:self.shield];
     self.shield.frame = controller.visibleViewController.view.bounds;
     CGRect frame = self.shield.frame;
     NSLog(@"[%f,%f,%f,%f]",frame.origin.x,frame.origin.y,frame.size.width,frame.size.height);    
}

-(void) completeSlideToSide:(UINavigationController*) controller{
    [self.shield removeFromSuperview];
    [controller.view addSubview:self.shield];
    self.shield.frame = controller.view.bounds;
    CGRect frame = self.shield.frame;
    NSLog(@"[%f,%f,%f,%f]",frame.origin.x,frame.origin.y,frame.size.width,frame.size.height);    
}

-(void) doSlideToSide{
    [UIView animateWithDuration:kSlideInInterval
                          delay:0.0
                        options:UIViewAnimationCurveEaseInOut
                     animations:^{
        [self slideToSide:selectedContent];
    }
                     completion:^(BOOL finished) {
        [self completeSlideToSide:selectedContent];
    }];
}

-(void) doSlideOut:(void (^)(BOOL completed))completion{
    [UIView animateWithDuration:kSlideOutInterval delay:0.0 options:UIViewAnimationCurveEaseInOut animations:^{
        [self slideOut:selectedContent];
    } completion:completion];
}

-(void) doSlideIn:(void (^)(BOOL completed))completion{
    [UIView animateWithDuration:kSlideInInterval delay:0.0 options:UIViewAnimationCurveEaseInOut animations:^{
        [self slideIn:selectedContent];
    } completion:^(BOOL finished) {
        if (completion) {
            completion(finished);            
        }
        [self completeSlideIn:selectedContent];
    }];
}

#pragma mark -
#pragma mark - SASlideMenuDynamicViewController

-(void) tapItem:(UIPanGestureRecognizer*)gesture{
    [self switchToContentViewController:selectedContent];
}

-(void) panItem:(UIPanGestureRecognizer*)gesture{
    UIView* panningView = gesture.view;
    CGPoint translation = [gesture translationInView:panningView];
    UIView* movingView = selectedContent.view;
    if (movingView.frame.origin.x + translation.x<0) {
        translation.x=0.0;
    }
    [movingView setCenter:CGPointMake([movingView center].x + translation.x, [movingView center].y)];
    [gesture setTranslation:CGPointZero inView:[panningView superview]];
    if ([gesture state] == UIGestureRecognizerStateEnded){
        CGFloat pcenterx = movingView.center.x;
        CGRect bounds = self.view.bounds;
        CGSize size = bounds.size;
        
        if (pcenterx > size.width ) {
            [self doSlideToSide];
        }else{            
            [self doSlideIn:nil];
        }
	}
}

-(void) switchToContentViewController:(UINavigationController*) content{
    CGRect bounds = self.view.bounds;
    self.view.userInteractionEnabled = NO;

    [self prepareForSwitchToContentViewController:content];

    Boolean slideOutThenIn = NO;
    if ([slideMenuDataSource respondsToSelector:@selector(slideOutThenIn)]){
        slideOutThenIn = [slideMenuDataSource slideOutThenIn];
    }
    
    if (slideOutThenIn) {
        //Animate out the currently selected UIViewController
        [self doSlideOut:^(BOOL completed) {
            [selectedContent willMoveToParentViewController:nil];
            [selectedContent.view removeFromSuperview];
            [selectedContent removeFromParentViewController];
            
            content.view.frame = CGRectMake(bounds.size.width,0,bounds.size.width,bounds.size.height);
            [self addChildViewController:content];
            [self.view addSubview:content.view];
            selectedContent = content;
            [self doSlideIn:^(BOOL completed) {
                [content didMoveToParentViewController:self];
                self.view.userInteractionEnabled = YES;
            }];
        }];
    }else{
        [selectedContent willMoveToParentViewController:nil];
        [selectedContent.view removeFromSuperview];
        [selectedContent removeFromParentViewController];
        [self slideToSide:content];
        [self addChildViewController:content];
        [self.view addSubview:content.view];
        selectedContent = content;
        [self doSlideIn:^(BOOL completed) {
            [content didMoveToParentViewController:self];
            self.view.userInteractionEnabled = YES;
        }];
    }    
}


-(void) addContentViewController:(UIViewController*) content withIndexPath:(NSIndexPath*)indexPath{
    CALayer* layer = [content.view layer];
    layer.shadowColor = [UIColor blackColor].CGColor;
    layer.shadowOpacity = 0.3;
    layer.shadowOffset = CGSizeMake(-15, 0);
    layer.shadowRadius = 10;
    layer.masksToBounds = NO;
    layer.shadowPath =[UIBezierPath bezierPathWithRect:layer.bounds].CGPath;
    Boolean allowContentViewControllerCaching = YES;
    if (indexPath) {
        if ([slideMenuDataSource respondsToSelector:@selector(allowContentViewControllerCachingForIndexPath:)]) {
            allowContentViewControllerCaching = [slideMenuDataSource allowContentViewControllerCachingForIndexPath:indexPath];
        }
        if (allowContentViewControllerCaching) {
            [self.controllers setObject:content forKey:indexPath];
        }
    }
}

-(void) prepareForSwitchToContentViewController:(UIViewController*) content{}

#pragma mark -
#pragma mark - UITableViewDelegate

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    self.selectedIndexPath = indexPath;
    UINavigationController* content = [self.controllers objectForKey:indexPath];
    if (content) {
        [self switchToContentViewController:content];
    }else{
        NSString* segueId = [self.slideMenuDataSource sugueIdForIndexPath:indexPath];
        UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self performSegueWithIdentifier:segueId sender:cell];
    }
}

#pragma mark -
#pragma mark - UIViewController

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (isFirstViewWillAppear) {
        NSString* identifier= [slideMenuDataSource initialSegueId];
        [self performSegueWithIdentifier:identifier sender:self];
        isFirstViewWillAppear = NO;
    }
}

-(void) viewDidLoad{
    [super viewDidLoad];
    
    isFirstViewWillAppear = YES;
    controllers = [[NSMutableDictionary alloc] init];
    self.shield = [[UIView alloc] initWithFrame:CGRectZero];
    /*
    UITapGestureRecognizer* tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapItem:)];
    [self.shield addGestureRecognizer:tapGesture];
    */
    
    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panItem:)];
    [panGesture setMaximumNumberOfTouches:2];
    [panGesture setDelegate:self];
    [self.shield addGestureRecognizer:panGesture];
    
}

-(void) didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    [self.controllers removeAllObjects];
}


@end