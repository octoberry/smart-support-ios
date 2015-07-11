//
//  ACAPIProvider.h
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ACUserModel.h"

@interface ACAPIProvider : NSObject

@property (nonatomic, readonly) NSString        *alias;
@property (nonatomic, readonly) NSURL           *URL;
@property (nonatomic, strong) NSString          *externalToken;

@property (nonatomic, readonly) NSString        *userName;
@property (nonatomic, strong) NSString          *userID;
@property (nonatomic, strong) NSString          *authorizationToken;



- (instancetype)initWithURL:(NSURL *)url
                      alias:(NSString *)alias
                      appId:(NSString *)appId
                    andName:(NSString *)name NS_DESIGNATED_INITIALIZER;



// API methods

// registration & authorization
- (void)apiRegisterWithCompletion:(void(^)(ACUserModel* userModel, NSError *error))completion;
- (void)apiTokenWithCompletion:(void(^)(NSError *error, NSString *token))completion;
- (void)apiUpdateTokenWithCompletion:(void(^)(NSError *error, NSString *token))completion;
- (void)apiMeWithCompletion:(void(^)(NSError *error, ACUserModel* user))completion;

// other stuff!..
- (void)apiRoomsWithCompletion:(void(^)(NSArray *rooms, NSError *error))completion;

- (void)apiUsersWithIDs:(NSArray *)IDs
             completion:(void(^)(NSError *error, NSArray *users))completion;

- (void)apiUpdateAvatarWithURLString:(NSString *)urlString
                          completion:(void(^)(NSError *error))completion;

- (void)apiUserAliasWithID:(NSString *)userID
                completion:(void(^)(NSError *error, NSString *alias))completion;

- (void)apiCreateRoomWithOpponent:(NSString *)opponentUser
                       completion:(void(^)(NSError *error, NSDictionary *room))completion;

- (void)apiUserWithAlias:(NSString *)alias
              completion:(void(^)(NSError *error, ACUserModel* user))completion;

- (void)apiReadMessage:(NSString *)messageID
            completion:(void(^)(NSError *error, NSDictionary *status))completion;

- (void)apiLastMessages:(NSNumber *)count
                   room:(NSString *)room
             completion:(void(^)(NSError *, NSArray *))completion;

- (void)apiFirstMessages:(NSNumber *)count
                    room:(NSString *)room
              completion:(void(^)(NSError *, NSArray *))completion;

- (void)apiHistoryForRoom:(NSString *)roomID
                    limit:(NSNumber*)limit
            lastMessageID:(NSString *)messageID
                  showNew:(BOOL)show
               completion:(void(^)(NSError *, NSArray *))completion;

- (void)apiUploadImage:(UIImage *)image
            completion:(void(^)(NSError *error, NSString *urlString))completion;

- (void)apiUploadImage:(UIImage *)image
              progress:(void(^)(CGFloat progress))progress
            completion:(void(^)(NSError *error, NSString *urlString))completion;

- (void)apiUploadFile:(NSData *)fileData
             fileName:(NSString *)name
          contentType:(NSString *)type
             progress:(void(^)(CGFloat progress))progress
           completion:(void(^)(NSError *error, NSString *urlString))completion;
@end
