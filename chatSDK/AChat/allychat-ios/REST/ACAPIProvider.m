//
//  ACAPIProvider.m
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACAPIProvider.h"
#import "ACAPIOperationManager.h"

#import <sys/utsname.h>
#import "ACUserModel.h"
#import "ACMessageModel.h"
#import "ACRoomModel.h"

#import "ACBaseModel+Protected.h"

@interface ACAPIProvider ()<ACAPIOperationManagerDelegate>

@property (nonatomic, strong) ACAPIOperationManager *operationManager;

@end

@implementation ACAPIProvider

static NSString  *_appId = nil;

-(instancetype)initWithURL:(NSURL *)url alias:(NSString *)alias appId:(NSString *)appId andName:(NSString *)name
{
    if (self = [super init]) {
        _URL = url;
        _alias = alias;
        _userName = name;
        _appId = appId;
        self.operationManager = [[ACAPIOperationManager alloc] initWithBaseURL:url];
        self.operationManager.delegate = self;
    }
    return self;
}

#pragma mark - api

- (void)apiTokenWithCompletion:(void(^)(NSError *error, NSString *token))completion {
    if (self.externalToken)
    {
        [self.operationManager performMethod:@"POST" apiPath:@"/api/token" query:nil parameters:@{@"App_id":_appId, @"alias":self.alias, @"auth_token":self.externalToken } completion:^(id response, NSError *error) {
            NSString *token = nil;
            if (!error) {
                token = response[@"token"];
            }
            completion(error, token);
        }];
    }
    else
    {
        completion([NSError errorWithDomain:@"com.allychat" code:400 userInfo:@{NSLocalizedDescriptionKey:@"External token could not be nill"}], nil);
    }    
}

- (void)apiUpdateTokenWithCompletion:(void(^)(NSError *error, NSString *token))completion
{
    [self.operationManager performMethod:@"POST" apiPath:@"/api/token" query:@{@"token":self.authorizationToken} parameters:nil completion:^(id response, NSError *error) {
        NSString *token = nil;
        if (!error) {
            token = response[@"token"];
        }
        completion(error, token);
    }];
}

- (void)apiMeWithCompletion:(void(^)(NSError *error, ACUserModel* user))completion {
    [self.operationManager performMethod:@"GET" apiPath:@"/api/me" query:@{@"token":self.authorizationToken} parameters:nil completion:^(id response, NSError *error) {
        if (completion) {
            completion(error, response);
        }
    }];
}

- (void)apiUploadImage:(UIImage *)image
              progress:(void(^)(CGFloat progress))progress
            completion:(void(^)(NSError *error, NSString *urlString))completion
{
    NSData *imageData = UIImageJPEGRepresentation(image, 1);
    NSString *fileName = [NSString stringWithFormat:@"%@.jpg", [[NSUUID UUID] UUIDString]];
    [self apiUploadFile:imageData fileName:fileName contentType:@"image/jpeg" progress:progress completion:completion];
}

- (void)apiUploadImage:(UIImage *)image
            completion:(void(^)(NSError *error, NSString *urlString))completion {
    [self apiUploadImage:image progress:nil completion:completion];
}


- (void)apiUploadFile:(NSData *)fileData
             fileName:(NSString *)name
          contentType:(NSString *)type
             progress:(void(^)(CGFloat progress))progress
           completion:(void(^)(NSError *error, NSString *urlString))completion
{
    [[self.operationManager performMultipartWithApiPath:@"/api/upload" query:@{@"token":self.authorizationToken} requestBodyConstruction:^(id<ACAPIMultipartConstructor> postData) {
        [postData appendPartWithFile:fileData name:@"file" fileName:name mimeType:type];
    } completion:^(id response, NSError *error) {
        if (completion) {
            if (response[@"file"]) {
                completion(error, response[@"file"]);
            }
            else
                completion(error, nil);
            
        }
    }] setUploadProgressBlock:progress? ^(NSUInteger bytesRead, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        progress(totalBytesWritten/totalBytesExpectedToWrite);
    } :nil];
}

- (void)apiLastMessages:(NSNumber *)count
                   room:(NSString *)room
             completion:(void(^)(NSError *, NSArray *))completion {
    [self apiHistoryForRoom:room limit:count lastMessageID:nil showNew:NO completion:completion];
}

- (void)apiFirstMessages:(NSNumber *)count
                    room:(NSString *)room
              completion:(void(^)(NSError *, NSArray *))completion {
    [self apiHistoryForRoom:room limit:count lastMessageID:nil showNew:YES completion:completion];
}

- (void)apiHistoryForRoom:(NSString *)roomID
                    limit:(NSNumber*)limit
            lastMessageID:(NSString *)messageID
                  showNew:(BOOL)show
               completion:(void(^)(NSError *, NSArray *))completion
{
    NSString *apiPath = [NSString stringWithFormat:@"/api/room/%@/messages", roomID];
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[@"token"] = self.authorizationToken;
    query[@"limit"] = [NSString stringWithFormat:@"%@", limit];
    if (messageID.length) {
        query[@"last_read_message"] = messageID;
    }
    query[@"show"] = (show?@"new":@"old");
    [self.operationManager performMethod:@"GET" apiPath:apiPath query:query parameters:nil completion:^(id response, NSError *error) {
        if (completion) {
            NSArray *messages = [response objectForKey:@"messages"];
            NSMutableArray *array = [NSMutableArray array];
            for (NSDictionary *d in messages) {
                ACMessageModel *r = [ACMessageModel modelWithDictionary:d];
                if (r) { [array addObject:r]; }
            }
            completion(error, array);
        }
    }];
}


- (void)apiReadMessage:(NSString *)messageID completion:(void(^)(NSError *error, NSDictionary *status))completion {
    NSString *apiPath = [NSString stringWithFormat:@"/api/message/%@/read", messageID];
    [self.operationManager performMethod:@"PUT" apiPath:apiPath query:@{@"token":self.authorizationToken} parameters:nil completion:^(id response, NSError *error) {
        if (completion) {
            
            NSError* serializationError;
            NSDictionary* json = [NSJSONSerialization JSONObjectWithData:response
                                                                 options:kNilOptions
                                                                   error:&serializationError];
            completion(error, json);
        }
    }];
}

- (void)apiUserWithAlias:(NSString *)alias
              completion:(void(^)(NSError *error, ACUserModel* user))completion
{
    [self.operationManager performMethod:@"GET" apiPath:@"/api/users" query:@{@"alias":alias, @"token":self.authorizationToken} parameters:nil completion:^(id response, NSError *error) {
        if (completion) {
            NSArray *array = response[@"users"];
            NSDictionary *dic = array.firstObject;
            ACUserModel* model = [ACUserModel modelWithDictionary:dic];
            completion(error, model);
        }
    }];
}
- (void)apiCreateRoomWithOpponent:(NSString *)opponentUser
                       completion:(void(^)(NSError *error, NSDictionary *room))completion
{
    [self.operationManager performMethod:@"POST" apiPath:[NSString stringWithFormat:@"/api/user/%@/rooms", self.userID] query:@{@"token":self.authorizationToken} parameters:@{@"user":opponentUser} completion:^(id response, NSError *error) {
        if (completion) {
            //room
            completion(error, response);
        }
    }];
}

- (void)apiUserAliasWithID:(NSString *)userID
                completion:(void(^)(NSError *error, NSString *alias))completion
{
    NSString *apiPath = [NSString stringWithFormat:@"/api/user/%@", userID];
    [self.operationManager performMethod:@"GET" apiPath:apiPath query:@{@"token":self.authorizationToken} parameters:nil completion:^(id response, NSError *error) {
        if (completion) {
            completion(error, response[@"alias"]);
        }
    }];
}

- (void)apiUpdateAvatarWithURLString:(NSString *)urlString
                          completion:(void(^)(NSError *error))completion
{
    NSString *apiPath = [NSString stringWithFormat:@"/api/user/%@", self.userID];
    [self.operationManager performMethod:@"POST" apiPath:apiPath query:@{@"token":self.authorizationToken} parameters:@{@"avatar_url":urlString?:@""} completion:^(id response, NSError *error) {
        if (completion) {
            completion(error);
        }
    }];
}

- (void)apiUsersWithIDs:(NSArray *)IDs
             completion:(void(^)(NSError *error, NSArray *users))completion
{
    NSMutableString *apiPath = [NSMutableString stringWithFormat:@"/api/users?token=%@", self.authorizationToken];
    for (NSString *userID in IDs) {
        [apiPath appendFormat:@"&id[]=%@", userID];
    }
    [self.operationManager performMethod:@"GET" apiPath:apiPath query:nil parameters:nil completion:^(id response, NSError *error) {
        if (completion) {
            NSMutableArray *array = [NSMutableArray array];
            for (NSDictionary *d in response[@"users"]) {
                ACUserModel *r = [ACUserModel modelWithDictionary:d];
                if (r) { [array addObject:r]; }
            }
            completion(error, array);
        }
    }];
}

- (void)apiRegisterWithCompletion:(void(^)(ACUserModel* userModel, NSError *error))completion {
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString *appBuild = [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSTimeZone *currentTimeZone = [NSTimeZone localTimeZone];
    
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *machineName = [NSString stringWithCString:systemInfo.machine
                                               encoding:NSUTF8StringEncoding];
    
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"alias"] = self.alias?:@"";
    if (self.userName) {
        dictionary[@"name"] = self.userName;
    }
    
    dictionary[@"os_version"] =[NSString stringWithFormat:@"%@/%@", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion]];
    dictionary[@"device_type"] = machineName?:@"Unknown";
    dictionary[@"app_version"] = [NSString stringWithFormat:@"%@/%@.%@", bundleID,appVersion, appBuild];
    dictionary[@"tzoffset"] = [NSString stringWithFormat:@"%td", [currentTimeZone secondsFromGMT]];
    //    if ([[ASLocationManager defaultManager] recentLocation]) {
    //        CLLocation *location = [[ASLocationManager defaultManager] recentLocation];
    //        dictionary[@"geolocation"] = [NSString stringWithFormat:@"%f, %f",location.coordinate.latitude, location.coordinate.longitude];
    //    }
    [self.operationManager performMethod:@"POST" apiPath:@"/api/user/register" query:nil parameters:dictionary completion:^(id response, NSError *error) {
        ACUserModel* user = [ACUserModel modelWithDictionary:response];
        if (completion) {
            completion(user, error);
        }
    }];
}

- (void)apiRoomsWithCompletion:(void(^)(NSArray *rooms, NSError *error))completion {
    NSString *apiPath = [NSString stringWithFormat:@"/api/user/%@/rooms", self.userID];
    [self.operationManager performMethod:@"GET" apiPath:apiPath query:@{@"token":self.authorizationToken} parameters:nil completion:^(id response, NSError *error) {
        if (completion) {
            NSMutableArray *array = [NSMutableArray array];
            for (NSDictionary *d in response[@"rooms"]) {
                ACRoomModel *r = [ACRoomModel modelWithDictionary:d];
                if (r) { [array addObject:r]; }
            }
            completion(array, error);
        }
    }];
}

#pragma mark ACAPIOperationManager Delegate Methods
-(void)externalTokenExpired
{
    self.externalToken = nil;
}

@end
