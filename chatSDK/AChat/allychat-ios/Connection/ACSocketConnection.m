//
//  ACSocketConnection.m
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACSocketConnection.h"
#import "ACConnection_Protected.h"

#import "SRWebSocket.h"
#import "ACBaseModel+Protected.h"

@interface ACSocketConnection () <SRWebSocketDelegate>

@property (nonatomic, strong) NSString          *socketHost;
@property (nonatomic, strong) SRWebSocket       *socket;

@property (nonatomic, strong) NSTimer           *timer;
@property (nonatomic, strong) NSMutableArray    *queue;

@end

@implementation ACSocketConnection

#pragma mark - helpers

- (NSURL *)socketURLForToken:(NSString *)token {
    return [NSURL URLWithString:[NSString stringWithFormat:@"wss://%@/relay?token=%@", self.socketHost, token]];
}

- (void)killCurrentSocket {
    if (self.socket) {
        self.socket.delegate = nil;
        [self.socket close];
        self.socket = nil;
    }
}



#pragma mark -

- (instancetype)initWithSocketHost:(NSString *)host {
    if (self = [super init]) {
        self.socketHost = host;
    }
    return self;
}

#pragma mark - public

- (void)connectWithToken:(NSString *)token {
    NSParameterAssert(token);
    NSAssert(self.socketHost, @"%s use `- (instancetype)initWithSocketHost:(NSString *)host` method for socket connection initialization.", __PRETTY_FUNCTION__);
    
    if (ACConnectionStatusDisconnected == self.innerConnectionStatus) {
        self.innerConnectionStatus = ACConnectionStatusConnecting;
        
        [self killCurrentSocket];
        
        self.socket = [[SRWebSocket alloc] initWithURL:[self socketURLForToken:token]];
        self.queue = [NSMutableArray array];
        self.socket.delegate = self;
        [self.socket open];
    }
}

- (void)disconnect {
    if (ACConnectionStatusDisconnected != self.innerConnectionStatus) {
        if (self.timer.isValid) {
            [self.timer invalidate];
            self.timer = nil;
        }
        [self killCurrentSocket];
        self.innerConnectionStatus = ACConnectionStatusDisconnected;
    }
}

- (void)sendMessage:(ACMessageModel*)message {
    NSParameterAssert(message);
    NSAssert(message.roomID != nil, @"Message to be sent should have information about room!");
    
    NSMutableDictionary *packetInfo = [NSMutableDictionary dictionary];
    [packetInfo setValue:@"message" forKey:@"type"];
    
    NSMutableDictionary *content = [NSMutableDictionary dictionary];
    [content setValue:message.message forKey:@"message"];
    [content setValue:message.roomID forKey:@"room"];
    [content setValue:[message.fileAttachmentURL absoluteString] forKey:@"file"];
    [packetInfo setValue:content forKey:@"content"];
    
    NSData *messageData = [NSJSONSerialization dataWithJSONObject:packetInfo options:0 error:nil];
    if (self.socket.readyState == SR_OPEN) {
        [self.socket send:messageData];
    } else {
        [self.queue addObject:messageData];
    }
}

#pragma mark - private

- (void)socketDidConnect {
    self.innerConnectionStatus = ACConnectionStatusConnected;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(pingAction:) userInfo:nil repeats:YES];
}

- (void)socketFailedToConnectWithError:(NSError *)error {
    [self disconnect];
}

#pragma mark - Ping

- (void)pingAction:(id)timer {
    if (self.socket.readyState == SR_OPEN) {
        [self.socket sendPing:nil];
    }
}


#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    id response = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
    if ([response isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dic = response;
        if ([dic[@"type"] isEqualToString:@"message"]) {
            ACMessageModel *message = [ACMessageModel modelWithDictionary:dic[@"content"]];
            [self.delegate connection:self didReceiveMessage:message];
        }
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    for (NSData* obj in self.queue) {
        [self.socket send:obj];
    }
    [self.queue removeAllObjects];
    [self socketDidConnect];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self socketFailedToConnectWithError:error];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self socketFailedToConnectWithError:nil];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
}

@end
