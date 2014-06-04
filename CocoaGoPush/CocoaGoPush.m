//
//  CocoaGoPush.m
//  CocoaGoPush
//
//  Created by Gdier on 14-4-5.
//  Copyright (c) 2014年 Gdier <gdier.zh@gmail.com> All rights reserved.
//

#import "CocoaGoPush.h"
#import "AsyncSocket.h"
#import <stdio.h>

// Socket
#define kGoPushProtocolComet                @"comet"

// HTTP
#define kGoPushProtocolSubcribe             @"/server/get"
#define kGoPushProtocolSubcribeServerKey    @"server"

// HTTP
#define kGoPushProtocolGetOfflineMessage    @"/msg/get"
#define kGoPushProtocolGetOfflineMessagePublicMsgKey    @"msgs"
#define kGoPushProtocolGetOfflineMessagePrivateMsgKey   @"pmsgs"

NSTimeInterval const CocoaGoPushDefaultNetworkTimeout = 5.f;
NSTimeInterval const CocoaGoPushHeartBeatInterval = 30.f;

#pragma mark - CocoaGoPushError

NSString * const kGoPushErrorDomain             = @"com.github.Terry-Mao.gopush-cluster";

NSString * const kGoPushErrorProtocolKey        = @"protocol";
NSString * const kGoPushErrorHTTPCodeKey        = @"httpCode";
NSString * const kGoPushErrorCustomMessageKey   = @"customMessage";

@interface CocoaGoPushError : NSError

+ (instancetype)errorWithCode:(GoPushErrorCode)errorCode exception:(NSException *)exception ofProtocol:(NSString *)protocol;
+ (instancetype)errorWithCode:(GoPushErrorCode)errorCode originalError:(NSError *)originalError ofProtocol:(NSString *)protocol;
+ (instancetype)errorWithCode:(GoPushErrorCode)errorCode ofProtocol:(NSString *)protocol;
+ (instancetype)errorWithHTTPCode:(NSInteger)httpCode ofProtocol:(NSString *)protocol;

@end

@implementation CocoaGoPushError

+ (instancetype)errorWithCode:(GoPushErrorCode)errorCode cusstomMessage:(NSString *)cusstomMessage ofProtocol:(NSString *)protocol {
    NSDictionary *userInfo = @{kGoPushErrorProtocolKey : protocol,
                               kGoPushErrorCustomMessageKey : cusstomMessage,
                               };
    
    CocoaGoPushError *error = [CocoaGoPushError errorWithDomain:kGoPushErrorDomain
                                                           code:errorCode
                                                       userInfo:userInfo];
    
    return error;
}

+ (instancetype)errorWithCode:(GoPushErrorCode)errorCode exception:(NSException *)exception ofProtocol:(NSString *)protocol {
    return [CocoaGoPushError errorWithCode:errorCode
                            cusstomMessage:[NSString stringWithFormat:@"Exception: %@,%@", exception.name, exception.reason]
                                ofProtocol:protocol];
}

+ (instancetype)errorWithCode:(GoPushErrorCode)errorCode originalError:(NSError *)originalError ofProtocol:(NSString *)protocol {
    return [CocoaGoPushError errorWithCode:errorCode
                            cusstomMessage:[originalError description]
                                ofProtocol:protocol];
}

+ (instancetype)errorWithCode:(GoPushErrorCode)errorCode ofProtocol:(NSString *)protocol {
    return [CocoaGoPushError errorWithCode:errorCode cusstomMessage:@"" ofProtocol:protocol];
}

+ (instancetype)errorWithHTTPCode:(NSInteger)httpCode ofProtocol:(NSString *)protocol {
    NSDictionary *userInfo = @{kGoPushErrorProtocolKey : protocol,
                               kGoPushErrorHTTPCodeKey : @(httpCode),
                               };
    
    CocoaGoPushError *error = [CocoaGoPushError errorWithDomain:kGoPushErrorDomain
                                                           code:GoPushErrorCode_HTTP
                                                       userInfo:userInfo];
    
    return error;
}

#ifdef COCOA_GOPUSH_ERROR_HAS_DESCRIPTION

- (NSString *)description {
    return [NSString stringWithFormat:@"CocoaGoPushError [%@, %@]",
            self.userInfo[kGoPushErrorProtocolKey],
            [self errorDescription]];
}

- (NSString *)errorDescription {
    NSString *text = nil;
    
    switch ((GoPushErrorCode)self.code) {
        case GoPushErrorCode_Network:
            text = @"Network";
            break;
            
        case GoPushErrorCode_HTTP:
            text = [NSString stringWithFormat:@"HTTP(%@)", self.userInfo[kGoPushErrorHTTPCodeKey]];
            break;
            
        case GoPushErrorCode_Unknown:
            text = @"Unknown";
            break;
            
        case GoPushErrorCode_Success:
            text = @"OK";
            break;
            
        case GoPushErrorCode_InvalidParameters:
            text = @"InvalidParameters(65534)";
            break;
            
        case GoPushErrorCode_ServerInside:
            text = @"ServerInside(65535)";
            break;
            
        default:
            NSAssert(NO, @"Unknown");
            text = [NSString stringWithFormat:@"Unknown(%ld)", (long)self.code];
    }
    
    if ([self.userInfo[kGoPushErrorCustomMessageKey] length] != 0)
        text = [text stringByAppendingFormat:@"<%@>", self.userInfo[kGoPushErrorCustomMessageKey]];
    
    return text;
}

#endif

@end

#pragma mark - ARC support

#if __has_feature(objc_arc)

@implementation NSObject (CocoaGoPush_ARC)

- (void)cgp_release {
}

- (id)cgp_retain {
    return self;
}

- (id)cgp_autorelease {
    return self;
}

- (id)cgp_dealloc {
    return self;
}

@end

#else

#define cgp_release release
#define cgp_retain retain
#define cgp_autorelease autorelease
#define cgp_dealloc dealloc

#endif

#pragma mark - CocoaGoPushMessage

@interface CocoaGoPushMessage ()

@property(nonatomic,retain) id msg;
@property(nonatomic) uint64_t mid;
@property(nonatomic) NSInteger gid;

@end

@implementation CocoaGoPushMessage

- (void)dealloc {
    self.msg = nil;
    
    [super cgp_dealloc];
}

+ (instancetype)messageFromDictionary:(NSDictionary *)dict {
    CocoaGoPushMessage *message = [[[CocoaGoPushMessage alloc] init] cgp_autorelease];
    
    message.msg = dict[@"msg"];
    message.mid = [dict[@"mid"] unsignedLongLongValue];
    message.gid = [dict[@"gid"] integerValue];
    
    return message;
}

@end

#pragma mark - CocoaGoPush

#ifdef COCOA_GOPUSH_ENABLE_LOG

void CocoaGoPushLog(NSString *format, ...) {
    va_list args;
    
    va_start(args, format);
    
    NSString *anotherFormat = [NSString stringWithFormat:@"[CocoaGoPush] %@\n", format];
    anotherFormat = [[[NSString alloc] initWithFormat:anotherFormat arguments:args] cgp_autorelease];
    
    printf("%s", [anotherFormat cStringUsingEncoding:NSUTF8StringEncoding]);
    
    va_end(args);
}

#else

void CocoaGoPushLog(NSString *format, ...) {
}

#endif

@interface CocoaGoPush () <AsyncSocketDelegate>

@property(atomic,copy)  NSString *host;
@property(atomic)       NSUInteger port;
@property(atomic,copy)  NSString *key;
@property(atomic)       CocoaGoPushState state;
@property(atomic,copy)  NSString *cometServerHost;
@property(atomic)       NSUInteger cometServerPort;

@property(atomic,retain) NSThread *workThread;
@property(atomic,retain) NSRunLoop *workRunloop;

@property(atomic,retain) AsyncSocket *cometSocket;
@property(atomic,retain) NSTimer *cometHeartBeatTimer;
@property(atomic,retain) NSMutableData *cometUnreadedResponseData;
@property(atomic,retain) NSMutableDictionary *cometResponseParsingContext;
@property(atomic,retain) NSMutableDictionary *lastMidMap;
@property(atomic,retain) NSMutableDictionary *cachedMessageMap;

@end

@implementation CocoaGoPush

- (void)dealloc {
    self.host   = nil;
    self.key    = nil;
    self.cometServerHost = nil;
    
    self.workThread = nil;
    self.workRunloop = nil;
    self.cometSocket = nil;
    self.cometHeartBeatTimer = nil;
    self.cometUnreadedResponseData = nil;
    self.cometResponseParsingContext = nil;
    self.lastMidMap = nil;
    self.cachedMessageMap = nil;
    
    CocoaGoPushLog(@"dealloc %p", self);

    [super cgp_dealloc];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.state = CocoaGoPushStateOffline;
        self.timeout = CocoaGoPushDefaultNetworkTimeout;
        
        CocoaGoPushLog(@"init %p", self);
    }
    return self;
}

- (instancetype)initWithServerHost:(NSString *)host port:(NSUInteger)port {
    self = [self init];
    if (self) {
        self.host = host;
        self.port = port;
    }
    return self;
}

- (void)connectWithKey:(NSString *)key {
    [self connectWithParam:@{@"k" : key}];
}

- (void)connectWithKey:(NSString *)key lastMidMap:(NSDictionary *)midMap {
    [self connectWithParam:@{@"k" : key, @"m" : midMap}];
}

- (void)connectWithParam:(NSDictionary *)params {
    if (nil == self.workThread) {
        self.workThread = [[[NSThread alloc] initWithTarget:self selector:@selector(workThreadProc) object:nil] cgp_autorelease];
        [self.workThread start];
    }
    
    if (![[NSThread currentThread] isEqual:self.workThread]) {
        [self performSelector:@selector(connectWithParam:) onThread:self.workThread withObject:params waitUntilDone:NO];
        return;
    }
    
    if (CocoaGoPushStateOffline != self.state) {
        return;
    }
    
    [self changeState:CocoaGoPushStateSubcribing];
    
    NSString *key = params[@"k"];
    NSDictionary *lastMidMap = params[@"m"];
    
    self.key = key;
    self.lastMidMap = [lastMidMap mutableCopy];
    
    [self subcribe];
    
    if (CocoaGoPushStateSubcribed != self.state)
        return;
    
    [self connectCometServer];
}

- (void)subcribe {
    
    CocoaGoPushLog(@"SubcribeWithKey %@", self.key);
    
    if (self.key.length == 0) {
        [self reportError:[CocoaGoPushError errorWithCode:GoPushErrorCode_InvalidParameters ofProtocol:kGoPushProtocolSubcribe]];
        return;
    }
    
    NSError *error = nil;
    NSDictionary *subcribeResult = [self callWebProtocolWithProtocol:kGoPushProtocolSubcribe
                                                          parameters:@{@"key" : self.key, @"proto" : @"2"}
                                                               error:&error];
    
    if (nil != error) {
        [self reportError:error];
        return;
    }
    
    NSString *server = subcribeResult[kGoPushProtocolSubcribeServerKey];
    if (nil == server) {
        [self reportError:[CocoaGoPushError errorWithCode:GoPushErrorCode_ProtoParse ofProtocol:kGoPushProtocolSubcribe]];
        return;
    }
    
    NSArray *serverComponents = [server componentsSeparatedByString:@":"];
    if (serverComponents.count != 2) {
        [self reportError:[CocoaGoPushError errorWithCode:GoPushErrorCode_ProtoParse ofProtocol:kGoPushProtocolSubcribe]];
        return;
    }
    
    CocoaGoPushLog(@"Subcribe Success With Server(%@)", server);
    
    [self changeState:CocoaGoPushStateSubcribed];
    
    self.cometServerHost = serverComponents[0];
    self.cometServerPort = [serverComponents[1] integerValue];
    
    if ([self.delegate respondsToSelector:@selector(cocoaGoPush:subcribedWith:)]) {
        [self.delegate cocoaGoPush:self subcribedWith:self.key];
    }
    
    return;
}

- (void)fetchOfflineMessages {
    if (self.state == CocoaGoPushStateFetchingOfflineMessage || self.state == CocoaGoPushStateReady)
        return;
    
    if (nil == self.lastMidMap) {
        [self changeState:CocoaGoPushStateReady];
        
        return;
    }
    
    if (nil == self.lastMidMap[@(CocoaGoPushGidPublic)] && nil == self.lastMidMap[@(CocoaGoPushGidPrivate)]) {
        [self changeState:CocoaGoPushStateReady];
        
        return;
    }
    
    [self changeState:CocoaGoPushStateFetchingOfflineMessage];
    
    [self performSelectorInBackground:@selector(fetchOfflineMessagesProc:)
                           withObject:@[self.workThread,
                                        @{@"key" : self.key,
                                          @"pmid" : self.lastMidMap[@(CocoaGoPushGidPublic)],
                                          @"mid" : self.lastMidMap[@(CocoaGoPushGidPrivate)],
                                          }
                                        ]];
}

- (void)fetchOfflineMessagesProc:(NSArray *)params {
    NSThread *workThread = params[0];
    NSDictionary *protoParam = params[1];
    NSError *error = nil;
    NSDictionary *subcribeResult = [self callWebProtocolWithProtocol:kGoPushProtocolGetOfflineMessage
                                                          parameters:protoParam
                                                               error:&error];
    
    if (nil != error) {
        [self performSelector:@selector(reportError:) onThread:workThread withObject:error waitUntilDone:NO];
    } else {
        [self performSelector:@selector(fetchOfflineMessagesReturn:) onThread:workThread withObject:subcribeResult waitUntilDone:NO];
    }
}

- (void)fetchOfflineMessagesReturn:(NSDictionary *)subcribeResult {
    NSDictionary *map = @{kGoPushProtocolGetOfflineMessagePublicMsgKey : @(CocoaGoPushGidPublic),
                          kGoPushProtocolGetOfflineMessagePrivateMsgKey : @(CocoaGoPushGidPrivate)};
    
    @try {
        [map enumerateKeysAndObjectsUsingBlock:^(NSString *key, id gidObject, BOOL *stop) {
            NSArray *messages;
            NSInteger gid = [gidObject integerValue];
            
            messages = subcribeResult[key];
            
            if (![messages isKindOfClass:[NSArray class]])
                return;
            
            for (NSString *messageText in messages) {
                id jsonObj = [NSJSONSerialization JSONObjectWithData:[messageText dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:0 error:nil];
                if (nil == jsonObj)
                    continue;
                
                CocoaGoPushMessage *message = [CocoaGoPushMessage messageFromDictionary:jsonObj];
                if (nil != message) {
//                    if (maxMid < message.mid)
//                        maxMid = message.mid;
                    
                    message.gid = gid;
                    
                    if (nil == self.cachedMessageMap)
                        self.cachedMessageMap = [NSMutableDictionary dictionary];
                    
                    NSMutableDictionary *gidMap = self.cachedMessageMap[gidObject];
                    
                    if (nil == gidMap) {
                        gidMap = [NSMutableDictionary dictionary];
                        [self.cachedMessageMap setObject:gidMap forKey:gidObject];
                    }
                    
                    self.cachedMessageMap[gidObject][@(message.mid)] = message;
                }
            }
            
//            self.lastMidMap[gidObject] = @(maxMid);
        }];
    }
    @catch (NSException *exception) {
    }
    
    [self changeState:CocoaGoPushStateReady];
    
    [self.cachedMessageMap enumerateKeysAndObjectsUsingBlock:^(id gidObject, NSDictionary *messages, BOOL *stop) {
        uint64_t maxMid;
        maxMid = [self.lastMidMap[gidObject] longLongValue];

        [messages enumerateKeysAndObjectsUsingBlock:^(id midObject, CocoaGoPushMessage *message, BOOL *stop) {
            if (maxMid < message.mid && [self.delegate respondsToSelector:@selector(cocoaGoPush:received:offlineMessage:)]) {
                [self.delegate cocoaGoPush:self received:message offlineMessage:YES];
            }
        }];
    }];
}

- (void)connectCometWithHost:(NSString *)host port:(NSInteger)port key:(NSString *)key {
    [self connectCometWithParam:@{@"h" : host, @"p" : @(port), @"k" : key}];
}

- (void)connectCometWithParam:(NSDictionary *)params {
    if (nil == self.workThread) {
        self.workThread = [[[NSThread alloc] initWithTarget:self selector:@selector(workThreadProc) object:nil] cgp_autorelease];
        [self.workThread start];
    }
    
    if (![[NSThread currentThread] isEqual:self.workThread]) {
        [self performSelector:@selector(connectCometWithParam:) onThread:self.workThread withObject:params waitUntilDone:NO];
        return;
    }
    
    if (CocoaGoPushStateOffline != self.state) {
        return;
    }

    self.key = params[@"k"];
    self.cometServerHost = params[@"h"];
    self.cometServerPort = [params[@"p"] integerValue];
    
    [self connectCometServer];
}

- (void)connectCometServer {
    [self changeState:CocoaGoPushStateConnecting];
    
    CocoaGoPushLog(@"Connecting Comet<%@:%d>", self.cometServerHost, self.cometServerPort);
    
    NSError *retError = nil;
    AsyncSocket *socket = [[[AsyncSocket alloc] initWithDelegate:self] cgp_autorelease];

    @try {
        BOOL retCode = [socket connectToHost:self.cometServerHost onPort:self.cometServerPort withTimeout:self.timeout error:&retError];
        if (!retCode || nil != retError) {
            [self reportError:[CocoaGoPushError errorWithCode:GoPushErrorCode_Network originalError:retError ofProtocol:kGoPushProtocolComet]];
            return;
        }
    }
    @catch (NSException *exception) {
        [self reportError:[CocoaGoPushError errorWithCode:GoPushErrorCode_Network exception:exception ofProtocol:kGoPushProtocolComet]];
        return;
    }
    
    self.cometSocket = socket;
    self.cometResponseParsingContext = [NSMutableDictionary dictionary];

    [self sendSubcribeCommandToCometServer];
}

- (void)disconnect {
    if (nil == self.workThread)
        return;
    
    if (![[NSThread currentThread] isEqual:self.workThread]) {
        [self performSelector:@selector(disconnect) onThread:self.workThread withObject:nil waitUntilDone:NO];
        return;
    }
    
    [self changeState:CocoaGoPushStateDisconnecting];
    
    [self cancelCometHeartBeat];
    
    if (nil != self.cometSocket) {
        [self.cometSocket disconnect];
    }
    
    [self.workThread cancel];
    self.workThread = nil;
    
    [self changeState:CocoaGoPushStateOffline];
}

- (void)workThreadProc {
    NSRunLoop *runloop = [NSRunLoop currentRunLoop];
    
    self.workRunloop = runloop;
    
    CocoaGoPushLog(@"WorkThreadProc start");
    
    while (YES) {
        [runloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        
        if ([[NSThread currentThread] isCancelled])
            break;
    }
    
    self.workRunloop = nil;
    
    CocoaGoPushLog(@"WorkThreadProc end");
}

- (void)changeState:(CocoaGoPushState)state {
    if (state == self.state)
        return;
    
    self.state = state;

    if ([self.delegate respondsToSelector:@selector(cocoaGoPush:stateChangeTo:)]) {
        [self.delegate cocoaGoPush:self stateChangeTo:state];
    }
}

- (void)reportError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(cocoaGoPush:reportError:)]) {
        [self.delegate cocoaGoPush:self reportError:error];
    }
    
    [self performSelector:@selector(disconnect) onThread:self.workThread withObject:nil waitUntilDone:NO];
}

- (NSString *)queryStringWithDictionary:(NSDictionary *)parameters {
    NSMutableArray *paramList = [[NSMutableArray alloc] initWithCapacity:[parameters count]];
    
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *param, id value, BOOL *stop) {
        [paramList addObject:[NSString stringWithFormat:@"%@=%@", param, [[value description] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    }];
    
    NSString *queryString = [paramList componentsJoinedByString:@"&"];
    
    [paramList cgp_release];
    
    return queryString;
}

- (NSDictionary *)callWebProtocolWithProtocol:(NSString *)protocol parameters:(NSDictionary *)parameters error:(NSError **)error {
    NSError *retError = nil;
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%lu%@?%@",
                           self.host, (unsigned long)self.port, protocol,
                           [self queryStringWithDictionary:parameters]];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                             cachePolicy:0
                                         timeoutInterval:self.timeout];

    NSHTTPURLResponse *response = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:&response
                                                             error:&retError];
    
    if (nil != retError || nil == responseData) {
        if (error)
            *error = [CocoaGoPushError errorWithCode:GoPushErrorCode_Network originalError:retError ofProtocol:protocol];
        return nil;
    }
    
    id responseObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&retError];
    if (nil != retError) {
        if (error)
            *error = [CocoaGoPushError errorWithCode:GoPushErrorCode_ProtoParse originalError:retError ofProtocol:protocol];
        return nil;
    }
    
    if (![response isKindOfClass:[NSHTTPURLResponse class]] || response.expectedContentLength != responseData.length) {
        if (error)
            *error = [CocoaGoPushError errorWithCode:GoPushErrorCode_Network ofProtocol:protocol];
        return nil;
    }
    
    if (200 != response.statusCode) {
        if (error)
            *error = [CocoaGoPushError errorWithHTTPCode:response.statusCode ofProtocol:protocol];
    }
    
    if (nil == responseObject || ![responseObject isKindOfClass:[NSDictionary class]]) {
        if (error)
            *error = [CocoaGoPushError errorWithCode:GoPushErrorCode_ProtoParse ofProtocol:protocol];
        return nil;
    }
    
    GoPushErrorCode errorCode = [responseObject[@"ret"] integerValue];
    if (GoPushErrorCode_Success != errorCode) {
        if (error)
            *error = [CocoaGoPushError errorWithCode:errorCode ofProtocol:protocol];
        return nil;
    }
    
    return responseObject[@"data"];
}

- (NSData *)buildCommandWithDictionary:(NSArray *)array {
    NSMutableString *commandString = [NSMutableString stringWithFormat:@"*%lu\r\n",
                                      (unsigned long)array.count];
    [array enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
        NSString *valueString = [value description];
        NSUInteger valueLength = [[valueString dataUsingEncoding:NSUTF8StringEncoding] length];
        [commandString appendFormat:@"$%lu\r\n%@\r\n", (unsigned long)valueLength, valueString];
    }];
    
    return [commandString dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)sendCometCommand:(NSArray *)command {
    NSData *commandData = [self buildCommandWithDictionary:command];
    if ([commandData length] == 0)
        return;
    
    [self.cometSocket writeData:commandData
                    withTimeout:CocoaGoPushDefaultNetworkTimeout tag:0];
}

- (void)sendSubcribeCommandToCometServer {
    NSArray *command = @[@"sub",
                         self.key,
                         @((int)CocoaGoPushHeartBeatInterval + CocoaGoPushDefaultNetworkTimeout),
                         @"",
                         @"1.0",
                         ];
    
    [self sendCometCommand:command];
}

- (void)nextCometHeartBeat {
    if (nil == self.cometHeartBeatTimer) {
        self.cometHeartBeatTimer = [NSTimer timerWithTimeInterval:CocoaGoPushHeartBeatInterval
                                                           target:self selector:@selector(cometHeartBeat)
                                                         userInfo:nil repeats:NO];
    }
    
    [self.workRunloop addTimer:self.cometHeartBeatTimer forMode:NSDefaultRunLoopMode];
}

- (void)cancelCometHeartBeat {
    if (nil == self.cometHeartBeatTimer)
        return;
    
    [self.cometHeartBeatTimer invalidate];
    self.cometHeartBeatTimer = nil;
}

- (void)cometHeartBeat {
    self.cometHeartBeatTimer = nil;

    CocoaGoPushLog(@"Comet pitpat");

    [self.cometSocket writeData:[@"h" dataUsingEncoding:NSUTF8StringEncoding]
                    withTimeout:CocoaGoPushDefaultNetworkTimeout tag:0];
}

- (void)parseResponseData:(NSData *)data {
    NSUInteger responseStart = 0;
    NSUInteger dataSize = [data length];
    const char *dataBytes = [data bytes];
    NSMutableArray *responseList = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < dataSize - 1; i ++) {
        if ('\r' != dataBytes[i] || '\n' != dataBytes[i + 1])
            continue;
        
        NSString *responseString = nil;
        
        if (0 == responseStart && nil != self.cometUnreadedResponseData) {
            [self.cometUnreadedResponseData appendBytes:dataBytes length:i];
            
            responseString = [[[NSString alloc] initWithData:self.cometUnreadedResponseData
                                                    encoding:NSUTF8StringEncoding] cgp_autorelease];
            
            self.cometUnreadedResponseData = nil;
        } else {
            responseString = [[[NSString alloc] initWithBytes:(dataBytes + responseStart)
                                                       length:(i - responseStart)
                                                     encoding:NSUTF8StringEncoding] cgp_autorelease];
        }
        
        CocoaGoPushLog(@"Comet say:\"%@\"", responseString);
        
        [responseList addObject:responseString];
        
        i += 2; // pass \r\n
        responseStart = i;
    }
    
    if (responseStart <= dataSize - 1) {
        self.cometUnreadedResponseData = [NSMutableData dataWithBytes:(dataBytes + responseStart) length:(dataSize - responseStart)];
    } else {
        self.cometUnreadedResponseData = nil;
    }
    
    [self parseResponseList:responseList];
    
    [self.cometSocket readDataWithTimeout:CocoaGoPushHeartBeatInterval + CocoaGoPushDefaultNetworkTimeout tag:0];
}

- (void)parseResponseList:(NSArray *)responseList {
#define kContextState           @"s"
#define kContextStateNew        0
#define kContextStateMessage    1

#define kContextMsgSize         @"ms"

    for (NSInteger lineno = 0; lineno < responseList.count; lineno ++) {
        NSString *line = responseList[lineno];
        
        switch ([self.cometResponseParsingContext[kContextState] integerValue]) {
            case kContextStateNew: {
                switch ([line characterAtIndex:0]) {
                    case '-': {
                        // error
                        [self reportError:[CocoaGoPushError errorWithCode:GoPushErrorCode_ProtoParse
                                                           cusstomMessage:[NSString stringWithFormat:@"Comet response -%c", [line characterAtIndex:1]]
                                                               ofProtocol:kGoPushProtocolComet]];

                        continue;
                    } break;
                        
                    case '+': {
                        switch ([line characterAtIndex:1]) {
                            case 'h':
                                // heartbeat
                                
                                if (self.state != CocoaGoPushStateReady) {
                                    [self fetchOfflineMessages];
                                }
                                
                                [self nextCometHeartBeat];
                                
                                continue;
                            default:
                                break;
                        }
                    } break;
                        
                    case '$': {
                        // msg
                        NSInteger msgSize = [[line substringFromIndex:1] integerValue];
                        
                        self.cometResponseParsingContext[kContextState] = @(kContextStateMessage);
                        self.cometResponseParsingContext[kContextMsgSize] = @(msgSize);
                        
                        continue;
                    } break;
                        
                    default:
                        break;
                }
            } break;
            case kContextStateMessage: {
                if ([line dataUsingEncoding:NSUTF8StringEncoding].length == [self.cometResponseParsingContext[kContextMsgSize] integerValue]) {
                    id msgDictionary = [NSJSONSerialization JSONObjectWithData:[line dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                    
                    if ([msgDictionary isKindOfClass:[NSDictionary class]]) {
                        
                        CocoaGoPushMessage *message = [CocoaGoPushMessage messageFromDictionary:msgDictionary];
                        if (nil != message) {
                            if (self.state != CocoaGoPushStateReady) {
                                if (nil == self.cachedMessageMap)
                                    self.cachedMessageMap = [NSMutableDictionary dictionary];
                                
                                NSMutableDictionary *gidMap = self.cachedMessageMap[@(message.gid)];
                                if (nil == gidMap) {
                                    gidMap = [NSMutableDictionary dictionary];
                                    [self.cachedMessageMap setObject:@(message.gid) forKey:gidMap];
                                }
                                
                                self.cachedMessageMap[@(message.gid)][@(message.mid)] = message;
                            } else {
                                if ([self.delegate respondsToSelector:@selector(cocoaGoPush:received:offlineMessage:)]) {
                                    [self.delegate cocoaGoPush:self received:message offlineMessage:NO];
                                }
                            }
                            
                            self.cometResponseParsingContext[kContextState] = @(kContextStateNew);
                            
                            continue;
                        }
                    }
                }
                
                CocoaGoPushLog(@"Comet invalid message: %@", line);
                
                self.cometResponseParsingContext[kContextState] = @(kContextStateNew);
                
                lineno --;
            } break;
        }

        CocoaGoPushLog(@"Comet invalid response: %@", line);
        
        self.cometResponseParsingContext[kContextState] = @(kContextStateNew);
    }
}

#pragma mark AsyncSocketDelegate

/**
 * In the event of an error, the socket is closed.
 * You may call "unreadData" during this call-back to get the last bit of data off the socket.
 * When connecting, this delegate method may be called
 * before"onSocket:didAcceptNewSocket:" or "onSocket:didConnectToHost:".
 **/
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
    if (![sock isEqual:self.cometSocket])
        return;
    
    if (nil != err) {
        [self reportError:[CocoaGoPushError errorWithCode:GoPushErrorCode_Network originalError:err ofProtocol:kGoPushProtocolComet]];
    }
}

/**
 * Called when a socket disconnects with or without error.  If you want to release a socket after it disconnects,
 * do so here. It is not safe to do that during "onSocket:willDisconnectWithError:".
 *
 * If you call the disconnect method, and the socket wasn't already disconnected,
 * this delegate method will be called before the disconnect method returns.
 **/
- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
    if (![sock isEqual:self.cometSocket])
        return;
    
    CocoaGoPushLog(@"Comet didDisconnect");
    sock.delegate = nil;
    
    [self disconnect];
}

/**
 * Called when a socket accepts a connection.  Another socket is spawned to handle it. The new socket will have
 * the same delegate and will call "onSocket:didConnectToHost:port:".
 **/
//- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket {
//    
//}

/**
 * Called when a new socket is spawned to handle a connection.  This method should return the run-loop of the
 * thread on which the new socket and its delegate should operate. If omitted, [NSRunLoop currentRunLoop] is used.
 **/
//- (NSRunLoop *)onSocket:(AsyncSocket *)sock wantsRunLoopForNewSocket:(AsyncSocket *)newSocket {
//    return nil;
//}

/**
 * Called when a socket is about to connect. This method should return YES to continue, or NO to abort.
 * If aborted, will result in AsyncSocketCanceledError.
 *
 * If the connectToHost:onPort:error: method was called, the delegate will be able to access and configure the
 * CFReadStream and CFWriteStream as desired prior to connection.
 *
 * If the connectToAddress:error: method was called, the delegate will be able to access and configure the
 * CFSocket and CFSocketNativeHandle (BSD socket) as desired prior to connection. You will be able to access and
 * configure the CFReadStream and CFWriteStream in the onSocket:didConnectToHost:port: method.
 **/
//- (BOOL)onSocketWillConnect:(AsyncSocket *)sock {
//    return YES;
//}

/**
 * Called when a socket connects and is ready for reading and writing.
 * The host parameter will be an IP address, not a DNS name.
 **/
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    if (![sock isEqual:self.cometSocket])
        return;
    
    CocoaGoPushLog(@"Comet didConnectTo<%@,%d>", host, port);
    [self.cometSocket readDataWithTimeout:CocoaGoPushHeartBeatInterval + CocoaGoPushDefaultNetworkTimeout tag:0];
}

/**
 * Called when a socket has completed reading the requested data into memory.
 * Not called if there is an error.
 **/
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (![sock isEqual:self.cometSocket])
        return;
    
    @try {
        [self parseResponseData:data];
    }
    @catch (NSException *exception) {
    }
}

/**
 * Called when a socket has read in data, but has not yet completed the read.
 * This would occur if using readToData: or readToLength: methods.
 * It may be used to for things such as updating progress bars.
 **/
//- (void)onSocket:(AsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
//    
//}

/**
 * Called when a socket has completed writing the requested data. Not called if there is an error.
 **/
//- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
//    
//}

/**
 * Called when a socket has written some data, but has not yet completed the entire write.
 * It may be used to for things such as updating progress bars.
 **/
//- (void)onSocket:(AsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
//    
//}

/**
 * Called if a read operation has reached its timeout without completing.
 * This method allows you to optionally extend the timeout.
 * If you return a positive time interval (> 0) the read's timeout will be extended by the given amount.
 * If you don't implement this method, or return a non-positive time interval (<= 0) the read will timeout as usual.
 *
 * The elapsed parameter is the sum of the original timeout, plus any additions previously added via this method.
 * The length parameter is the number of bytes that have been read so far for the read operation.
 *
 * Note that this method may be called multiple times for a single read if you return positive numbers.
 **/
//- (NSTimeInterval)onSocket:(AsyncSocket *)sock
//  shouldTimeoutReadWithTag:(long)tag
//                   elapsed:(NSTimeInterval)elapsed
//                 bytesDone:(NSUInteger)length {
//    return 0;
//}

/**
 * Called if a write operation has reached its timeout without completing.
 * This method allows you to optionally extend the timeout.
 * If you return a positive time interval (> 0) the write's timeout will be extended by the given amount.
 * If you don't implement this method, or return a non-positive time interval (<= 0) the write will timeout as usual.
 *
 * The elapsed parameter is the sum of the original timeout, plus any additions previously added via this method.
 * The length parameter is the number of bytes that have been written so far for the write operation.
 *
 * Note that this method may be called multiple times for a single write if you return positive numbers.
 **/
//- (NSTimeInterval)onSocket:(AsyncSocket *)sock
// shouldTimeoutWriteWithTag:(long)tag
//                   elapsed:(NSTimeInterval)elapsed
//                 bytesDone:(NSUInteger)length {
//    return 0;
//}

/**
 * Called after the socket has successfully completed SSL/TLS negotiation.
 * This method is not called unless you use the provided startTLS method.
 *
 * If a SSL/TLS negotiation fails (invalid certificate, etc) then the socket will immediately close,
 * and the onSocket:willDisconnectWithError: delegate method will be called with the specific SSL error code.
 **/
//- (void)onSocketDidSecure:(AsyncSocket *)sock {
//    
//}

@end
