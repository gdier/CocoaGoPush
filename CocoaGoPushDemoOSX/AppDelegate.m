//
//  AppDelegate.m
//  CocoaGoPushDemoOSX
//
//  Created by Gdier on 14-4-5.
//  Copyright (c) 2014年 Gdier <gdier.zh@gmail.com>. All rights reserved.
//

#import "AppDelegate.h"
#import "CocoaGoPush.h"

@interface AppDelegate () <CocoaGoPushDelegate>

@property(nonatomic,retain) CocoaGoPush *goPush;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (IBAction)onConnect:(id)sender {
    if (nil == self.goPush) {
#if __has_feature(objc_arc)
        
        self.goPush = [[CocoaGoPush alloc] initWithServerHost:@"10.20.216.169" port:8090];
        
#else
        
        self.goPush = [[[CocoaGoPush alloc] initWithServerHost:@"10.20.216.169" port:8090] autorelease];
        
#endif
        self.goPush.delegate = self;
    }
    
    [self.goPush connectWithKey:@"testKey" lastMidMap:@{@(CocoaGoPushGidPrivate) : @(0),
                                                        @(CocoaGoPushGidPublic) : @(0),
                                                        }];
}

- (IBAction)onDisconnect:(id)sender {
    [self.goPush disconnect];
    //    self.goPush = nil;
}

- (IBAction)onFree:(id)sender {
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
    NSLog(@"%d %llu %@", offlineMessage, message.mid, message.msg);
}

@end
