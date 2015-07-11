//
//  ACConnection.m
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACConnection.h"
#import "ACConnection_Protected.h"

@implementation ACConnection

#pragma mark - initialization

- (instancetype)init {
    if (self = [super init]) {
        self.innerConnectionStatus = ACConnectionStatusDisconnected;
    }
    return self;
}

#pragma mark - connection status

- (ACConnectionStatus)connectionStatus {
    return _innerConnectionStatus;
}

- (void)setInnerConnectionStatus:(ACConnectionStatus)innerConnectionStatus {
    if (_innerConnectionStatus != innerConnectionStatus) {
        _innerConnectionStatus = innerConnectionStatus;
        [self.delegate connection:self didChangeConnectionStatus:_innerConnectionStatus];
    }
}

#pragma mark - base methods

- (void)connectWithToken:(NSString *)token {
    //
}

- (void)disconnect {
    //
}

- (void)sendMessage:(ACMessageModel*)message {
    // 
}

@end
