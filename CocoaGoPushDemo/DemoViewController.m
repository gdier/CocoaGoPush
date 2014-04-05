//
//  DemoViewController.m
//  CocoaGoPush
//
//  Created by Gdier on 14-4-5.
//  Copyright (c) 2014年 Gdier <gdier.zh@gmail.com>. All rights reserved.
//

#import "DemoViewController.h"
#import "CocoaGoPush.h"

@interface DemoViewController () <CocoaGoPushDelegate>

@property(nonatomic,retain) CocoaGoPush *goPush;

@end

@implementation DemoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onConnect {
    if (nil == self.goPush) {
#if __has_feature(objc_arc)
        
        self.goPush = [[CocoaGoPush alloc] initWithServerHost:@"10.20.216.169" port:8090];
        
#else
        
        self.goPush = [[[CocoaGoPush alloc] initWithServerHost:@"10.20.216.169" port:8090] autorelease];
        
#endif
        self.goPush.delegate = self;
    }
    
    [self.goPush connectWithKey:@"testKey"];
}

- (IBAction)onDisconnect {
    [self.goPush disconnect];
    //    self.goPush = nil;
}

- (IBAction)onFree {
    [self.goPush disconnect];
    self.goPush = nil;
    //    self.goPush = nil;
}

#pragma mark - CocoaGoPushDelegate

- (void)cocoaGoPush:(CocoaGoPush *)goPush reportError:(NSError *)error {
    NSLog(@"%@", error);
}

- (void)cocoaGoPush:(CocoaGoPush *)goPush subcribedWith:(NSString *)key result:(BOOL)success {
    
}

- (void)cocoaGoPush:(CocoaGoPush *)goPush stateChangeTo:(CocoaGoPushState)state {
    
}

- (void)cocoaGoPush:(CocoaGoPush *)goPush received:(CocoaGoPushMessage *)message offlineMessage:(BOOL)offlineMessage {
    NSLog(@"%@", message.msg);
}

@end
