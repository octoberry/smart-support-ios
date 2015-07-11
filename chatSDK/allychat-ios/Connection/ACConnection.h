//
//  ACConnection.h
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACMessageModel.h"

typedef NS_ENUM(NSUInteger, ACConnectionStatus) {
    ACConnectionStatusDisconnected,
    ACConnectionStatusConnecting,
    ACConnectionStatusConnected
};

@class ACConnection;
@protocol ACConnectionDelegate <NSObject>

- (void)connection:(ACConnection *)connection didChangeConnectionStatus:(ACConnectionStatus)connectionStatus;
- (void)connection:(ACConnection *)connection didReceiveMessage:(ACMessageModel*)message;

@end

@interface ACConnection : NSObject

@property (nonatomic, readonly) ACConnectionStatus      connectionStatus;
@property (nonatomic, weak) id <ACConnectionDelegate>   delegate;

- (void)connectWithToken:(NSString *)token;
- (void)disconnect;

- (void)sendMessage:(ACMessageModel *)message;

@end
