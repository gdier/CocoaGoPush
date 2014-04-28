//
//  CocoaGoPush.h
//  CocoaGoPush
//
//  Created by Gdier on 14-4-5.
//  Copyright (c) 2014年 Gdier <gdier.zh@gmail.com> All rights reserved.
//


#import <Foundation/Foundation.h>

#ifdef DEBUG
#   define COCOA_GOPUSH_ERROR_HAS_DESCRIPTION
#   define COCOA_GOPUSH_ENABLE_LOG
#endif

@class CocoaGoPush;
@class CocoaGoPushMessage;

extern NSString * const kGoPushErrorDomain;
extern NSString * const kGoPushErrorProtocolKey;
extern NSString * const kGoPushErrorHTTPCodeKey;
extern NSString * const kGoPushErrorCustomMessageKey;

typedef NS_ENUM(NSInteger, GoPushErrorCode) {
    GoPushErrorCode_Unknown             = -4,
    GoPushErrorCode_Network             = -3,
    GoPushErrorCode_HTTP                = -2,
    GoPushErrorCode_ProtoParse          = -1,
    GoPushErrorCode_Success             = 0,
    GoPushErrorCode_InvalidParameters   = 65534,
    GoPushErrorCode_ServerInside        = 65535,
};

typedef NS_ENUM(NSInteger, CocoaGoPushState) {
    CocoaGoPushStateOffline = 0,
    CocoaGoPushStateSubcribing,
    CocoaGoPushStateSubcribed,
    CocoaGoPushStateFetchingOfflineMessage,
    CocoaGoPushStateConnecting,
    CocoaGoPushStateReady,
    CocoaGoPushStateDisconnecting,
};

typedef NS_ENUM(NSInteger, CocoaGoPushGid) {
    CocoaGoPushGidPrivate = 0,
    CocoaGoPushGidPublic = 1,
};

extern NSTimeInterval const CocoaGoPushDefaultNetworkTimeout;

@protocol CocoaGoPushDelegate <NSObject>

@optional

- (void)cocoaGoPush:(CocoaGoPush *)goPush reportError:(NSError *)error;
- (void)cocoaGoPush:(CocoaGoPush *)goPush subcribedWith:(NSString *)key;
- (void)cocoaGoPush:(CocoaGoPush *)goPush stateChangeTo:(CocoaGoPushState)state;
- (void)cocoaGoPush:(CocoaGoPush *)goPush received:(CocoaGoPushMessage *)message offlineMessage:(BOOL)offlineMessage;

@end

@interface CocoaGoPushMessage : NSObject

@property(nonatomic,retain,readonly) id msg;
@property(nonatomic,readonly) uint64_t mid;
@property(nonatomic,readonly) NSInteger gid; /* see CocoaGoPushGid */

@end

@interface CocoaGoPush : NSObject

@property(atomic,copy,readonly) NSString *host;
@property(atomic,readonly) NSUInteger port;
@property(atomic,copy,readonly) NSString *key;
@property(atomic,readonly) CocoaGoPushState state;

@property(atomic) NSTimeInterval timeout;
@property(atomic,assign) id<CocoaGoPushDelegate> delegate;

- (instancetype)initWithServerHost:(NSString *)host port:(NSUInteger)port;

- (void)connectWithKey:(NSString *)key;
- (void)connectWithKey:(NSString *)key lastMidMap:(NSDictionary *)midMap;
- (void)connectCometWithHost:(NSString *)host port:(NSInteger)port key:(NSString *)key;
- (void)disconnect;

@end
