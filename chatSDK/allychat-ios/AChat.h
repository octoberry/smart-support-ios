//
//  ACEngine.h
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACUserInfoModel.h"
#import "ACMessageModel.h"

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, AChatStatus) {
    AChatStatusOffline,
    AChatStatusConnecting,
    AChatStatusOnline
};

@class AChat;
@protocol AChatDelegate <NSObject>
- (void)chat:(AChat *)engine didUpdateStatusFromStatus:(AChatStatus)oldSstatus toStatus:(AChatStatus)newStatus;
- (void)chat:(AChat *)engine didReceiveMessage:(ACMessageModel *)message;
@end

@interface AChat : NSObject

@property (nonatomic, readonly) NSURL           *URL;
@property (nonatomic, readonly) NSString        *alias;
@property (nonatomic, readonly) AChatStatus     status;
@property (nonatomic, readonly) ACUserInfoModel *userInfoModel;

@property (nonatomic, weak) id<AChatDelegate> delegate;

- (instancetype)initWithURL:(NSURL *)url alias:(NSString *)alias NS_DESIGNATED_INITIALIZER;

- (void)roomsWithCompletion:(void(^)(NSArray *rooms, NSError *error))completion;

- (void)sendImageMessage:(UIImage *)image
                    room:(NSString *)roomID;

//- (void)sendImageMessage:(UIImage *)image
//                    room:(NSString *)roomID
//                progress:()

- (void)sendTextMessage:(NSString *)text
                   room:(NSString *)roomID;

- (void)usersWithIDs:(NSArray *)IDs
             completion:(void(^)(NSError *error, NSArray *users))completion;

- (void)updateAvatarWithURLString:(NSString *)urlString
                          completion:(void(^)(NSError *error))completion;

- (void)userAliasWithID:(NSString *)userID
                completion:(void(^)(NSError *error, NSString *alias))completion;

- (void)createRoomWithOpponent:(NSString *)opponentUser
                       completion:(void(^)(NSError *error, NSDictionary *room))completion;

- (void)userWithAlias:(NSString *)alias
              completion:(void(^)(NSError *error, ACUserModel* user))completion;

- (void)readMessage:(NSString *)messageID
            completion:(void(^)(NSError *error))completion;

- (void)lastMessages:(NSNumber *)count
                   room:(NSString *)room
             completion:(void(^)(NSError *, NSArray *))completion;

- (void)firstMessages:(NSNumber *)count
                    room:(NSString *)room
              completion:(void(^)(NSError *, NSArray *))completion;

- (void)historyForRoom:(NSString *)roomID
                    limit:(NSNumber*)limit
            lastMessageID:(NSString *)messageID
                  showNew:(BOOL)show
               completion:(void(^)(NSError *, NSArray *))completion;

@end
