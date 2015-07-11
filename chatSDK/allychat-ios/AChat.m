//
//  ACEngine.m
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "AChat.h"
#import "ACAPIProvider.h"
#import "ACSocketConnection.h"
#import "ACUserInfoModel.h"
#import "NSObject+MethodsDependency.h"

#import "ACAPIOperationManager.h"

/*
my.allychat.ru
admin
1vFamm
*/

@interface AChat () <ACConnectionDelegate>
@property (nonatomic, assign, readwrite) AChatStatus     status;

@property (nonatomic, strong) ACAPIProvider             *apiProvider;
@property (nonatomic, strong) ACConnection              *socketConnection;

@property (nonatomic, readonly) NSString                *authorizationToken;

@property (nonatomic, strong, readwrite) ACUserInfoModel *userInfoModel;

@property (nonatomic, strong) void (^connectCompletion)(NSError *error);

@property (nonatomic, assign) BOOL              tokenUpdating;
@property (atomic, strong) NSMutableArray       *blocks;

@end

@implementation AChat

#pragma mark - initialization

- (instancetype)initWithURL:(NSURL *)url alias:(NSString *)alias {
    if (self = [super init]) {
        _URL = url;
        
        _userInfoModel = [[ACUserInfoModel alloc] initWithAlias:alias];
        self.apiProvider = [[ACAPIProvider alloc] initWithURL:self.URL alias:alias];
        
        self.blocks = [NSMutableArray array];
        
        typeof(self) __weak self_weak = self;
        [self md_registerMethod:@"connect" condition:^BOOL{ return self_weak.status == AChatStatusOnline; } selector:@selector(connectWithCompletion:)];
        [self md_registerMethod:@"token" condition:^BOOL{ return self_weak.authorizationToken; } selector:@selector(tokenWithCompletion:)];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenExpireNotification:) name:ACAPIOperationManagerTokenExpireNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notification's

- (void)performBlockWithValidToken:(void(^)( NSError *error ))block {
    if (!block) return;
    
    if (self.apiProvider.authorizationToken.length) {
        block(nil);
    } else {
        [self.blocks addObject:block];
        if (!self.tokenUpdating) {
            [self tokenExpireNotification:nil];
        }
    }
}

- (void)tokenExpireNotification:(NSNotification *)note {
    self.apiProvider.authorizationToken = nil;
    self.tokenUpdating = YES;
    [self.socketConnection disconnect];
    
    typeof(self) __weak self_weak = self;
    [self tokenWithCompletion:^(NSError *error) {
        typeof (self_weak) self = self_weak;
        self.tokenUpdating = NO;
        for (void(^block)(NSError *error) in self.blocks) {
            block(error);
        }
        [self.blocks removeAllObjects];
        if (!error) {
            [self.socketConnection connectWithToken:self.apiProvider.authorizationToken];
        }
    }];
}

- (void)applicationDidEnterBackground:(NSNotification *)note {
    [self disconnect];
}

- (void)applicationWillEnterForeground:(NSNotification *)note {
    self.userInfoModel.rooms = nil;
    [self md_dependencyWithName:@"connect" error:nil success:nil];
}

#pragma mark - getters

- (NSString *)authorizationToken {
    return self.apiProvider.authorizationToken;
}

- (NSString *)alias {
    return self.userInfoModel.user.alias;
}

#pragma mark - api's

#pragma mark - connection

- (void)connectWithCompletion:(void(^)(NSError *error))completion {
    // TODO: detect current connection status and prevent
    self.connectCompletion = completion;
    
    [self innerConnect];
}

- (void)disconnect {
    [self.socketConnection disconnect];
    self.apiProvider.authorizationToken = nil;
    //other actions
}

// this method is optimal to use when the app went from background / etc
- (void)innerConnect {
    if (!self.apiProvider) {
        self.apiProvider = [[ACAPIProvider alloc] initWithURL:self.URL alias:self.userInfoModel.user.alias];
    }
    
    if (!self.socketConnection) {
        self.socketConnection = [[ACSocketConnection alloc] initWithSocketHost:self.URL.host];
        self.socketConnection.delegate = self;
    }
    
    // update connection status...
    
    // should we register our user?
    if (!self.userInfoModel.user.userID) {
        [self connectRegister];
    } else if (!self.authorizationToken) { // or token expired...
        [self connectAuthorize];
    } else if (!self.userInfoModel.rooms) { // rooms.count could be zero, but rooms should be not nil (!)
        // check rooms...
        [self connectRooms];
    } else if (self.socketConnection.connectionStatus == ACConnectionStatusDisconnected) {
        [self connectSocket];
    } else {
        [self connectDone];
    }
}

- (void)tokenWithCompletion:(void(^)(NSError *error))completion {
    typeof(self) __weak self_weak = self;
    [self md_dependencyWithName:@"connect" error:^(NSError *error) {
        completion(error);
    } success:^{
        typeof(self_weak) self = self_weak;
        if (!self.authorizationToken) {
            [self.apiProvider apiTokenWithCompletion:^(NSError *error, NSString *token) {
                self.apiProvider.authorizationToken = token;
                completion(error);
            }];
        } else {
            completion(nil);
        }
    }];
}

#pragma mark * connection errors

- (void)connectHandleError:(NSError *)error {
    // change connection status
    
    // notify delegate
    if (self.connectCompletion) {
        self.connectCompletion(error);
        self.connectCompletion = nil;
    }
}

#pragma mark * connection steps

- (void)connectRegister {
    __weak typeof (self) selfRef = self;
    [self.apiProvider apiRegisterWithCompletion:^(ACUserModel* userModel, NSError *error) {
        if (!error) {
            selfRef.userInfoModel.user = userModel;
            selfRef.apiProvider.userID = userModel.userID;
            [selfRef innerConnect];
        } else {
            [selfRef connectHandleError:error];
        }
    }];
}

- (void)connectAuthorize {
    __weak typeof (self) selfRef = self;
    [self.apiProvider apiTokenWithCompletion:^(NSError *error, NSString *token) {
        if (!error) {
            selfRef.apiProvider.authorizationToken = token;
            [selfRef innerConnect];
        } else {
            [selfRef connectHandleError:error];
        }
    }];
}

- (void)connectRooms {
    __weak typeof (self) selfRef = self;
    [self.apiProvider apiRoomsWithCompletion:^(NSArray *rooms, NSError *error) {
        if (!error) {
            selfRef.userInfoModel.rooms = rooms;
            [selfRef innerConnect];
        } else {
            [selfRef connectHandleError:error];
        }
    }];
}

- (void)connectSocket {
    [self.socketConnection connectWithToken:self.authorizationToken];
    [self innerConnect];
}

- (void)connectDone {
    if (self.connectCompletion) {
        self.connectCompletion(nil);
        self.connectCompletion = nil;
    }
}

#pragma mark - ACConnectionDelegate

- (void)connectAfterDelay {
    typeof(self) __weak self_weak = self;
    [self md_dependencyWithName:@"connect" error:^(NSError *error) {
        if ([error.userInfo[@"HTTPResponseStatusCode"] integerValue] == 401 || [error.userInfo[@"HTTPResponseStatusCode"] integerValue] == 403) {
            typeof(self_weak) self = self_weak;
            [self tokenExpireNotification:nil];
        } else {
            NSLog(@"AllyChat[Error]: Socket close with error: %@", error);
        }
    } success:nil];
    
}

- (void)connection:(ACConnection *)connection didChangeConnectionStatus:(ACConnectionStatus)connectionStatus {
    AChatStatus oldStatus = self.status;
    switch (connectionStatus) {
        case ACConnectionStatusDisconnected: {
            self.status = AChatStatusOffline;
            break;
        }
        case ACConnectionStatusConnecting: {
            self.status = AChatStatusConnecting;
            break;
        }
        case ACConnectionStatusConnected: {
            self.status = AChatStatusOnline;
            break;
        }
        default: {
            break;
        }
    }
    [self.delegate chat:self didUpdateStatusFromStatus:oldStatus toStatus:self.status];
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground) {
        [self performSelector:@selector(connectAfterDelay) withObject:nil afterDelay:5.0];
    }
}

- (void)connection:(ACConnection *)connection didReceiveMessage:(ACMessageModel *)message {
    [self.delegate chat:self didReceiveMessage:message];
}

#pragma mark * Public

- (void)roomsWithCompletion:(void(^)(NSArray *rooms, NSError *error))completion {
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(nil, error); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiRoomsWithCompletion:completion];
    }];
}

- (void)usersWithIDs:(NSArray *)IDs
          completion:(void(^)(NSError *error, NSArray *users))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiUsersWithIDs:IDs completion:completion];
    }];
}

- (void)updateAvatarWithURLString:(NSString *)urlString
                       completion:(void(^)(NSError *error))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiUpdateAvatarWithURLString:urlString completion:completion];
    }];
}

- (void)userAliasWithID:(NSString *)userID
             completion:(void(^)(NSError *error, NSString *alias))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiUserAliasWithID:userID completion:completion];
    }];
}

- (void)createRoomWithOpponent:(NSString *)opponentUser
                    completion:(void(^)(NSError *error, NSDictionary *room))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiCreateRoomWithOpponent:opponentUser completion:completion];
    }];
}

- (void)userWithAlias:(NSString *)alias
           completion:(void(^)(NSError *error, ACUserModel* user))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiUserWithAlias:alias completion:completion];
    }];
}

- (void)readMessage:(NSString *)messageID
         completion:(void(^)(NSError *error))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiReadMessage:messageID completion:completion];
    }];
}

- (void)lastMessages:(NSNumber *)count
                room:(NSString *)room
          completion:(void(^)(NSError *, NSArray *))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiLastMessages:count room:room completion:completion];
    }];
}

- (void)firstMessages:(NSNumber *)count
                 room:(NSString *)room
           completion:(void(^)(NSError *, NSArray *))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiFirstMessages:count room:room completion:completion];
    }];
}

- (void)historyForRoom:(NSString *)roomID
                 limit:(NSNumber*)limit
         lastMessageID:(NSString *)messageID
               showNew:(BOOL)show
            completion:(void(^)(NSError *, NSArray *))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiHistoryForRoom:roomID limit:limit lastMessageID:messageID showNew:show completion:completion];
    }];
}

- (void)uploadImage:(UIImage *)image
         completion:(void(^)(NSError *error, NSString *urlString))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiUploadImage:image completion:completion];
    }];
}

- (void)uploadImage:(UIImage *)image
           progress:(void(^)(CGFloat progress))progress
         completion:(void(^)(NSError *error, NSString *urlString))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiUploadImage:image progress:progress completion:completion];
    }];
}

- (void)uploadFile:(NSData *)fileData
          fileName:(NSString *)name
       contentType:(NSString *)type
          progress:(void(^)(CGFloat progress))progress
        completion:(void(^)(NSError *error, NSString *urlString))completion
{
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            if (completion) { completion(error, nil); }
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiUploadFile:fileData fileName:name contentType:type progress:progress completion:completion];
    }];
}

- (void)sendTextMessage:(NSString *)text room:(NSString *)roomID {
    typeof(self) __weak self_weak = self;
    [self md_dependencyWithName:@"connect" error:nil success:^{
        typeof(self_weak) self = self_weak;
        ACMessageModel *message = [ACMessageModel modelWithDictionary:@{@"message":text?:@"", @"room":roomID}];
        [self.socketConnection sendMessage:message];
    }];
}

- (void)sendImageMessage:(UIImage *)image room:(NSString *)roomID {
    typeof(self) __weak self_weak = self;
    [self performBlockWithValidToken:^(NSError *error) {
        if (error) {
            return;
        }
        typeof(self_weak) self = self_weak;
        [self.apiProvider apiUploadImage:image completion:^(NSError *error, NSString *urlString) {
            if (!error) {
                ACMessageModel *message = [ACMessageModel modelWithDictionary:@{@"room":roomID}];
                message.fileAttachmentURL = [NSURL URLWithString:urlString];
                [self.socketConnection sendMessage:message];
            }
        }];
    }];
}

@end
