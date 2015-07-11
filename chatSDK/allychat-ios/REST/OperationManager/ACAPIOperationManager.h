//
//  ACAPIOperationManager.h
//  ACChat
//
//  Created by Alex on 6/17/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACAPIOperation.h"

@protocol ACAPIMultipartConstructor <NSObject>

- (void)appendPartWithFile:(NSData *)file
                      name:(NSString *)name
                  fileName:(NSString *)fileName
                  mimeType:(NSString *)mimeType;

- (void)appendPartWithData:(NSData *)data
                      name:(NSString *)name;
@end

extern NSString *const ACAPIOperationManagerTokenExpireNotification;

@interface ACAPIOperationManager : NSObject
@property (nonatomic, readonly) NSURL *baseURL;

- (instancetype)initWithBaseURL:(NSURL *)url  NS_DESIGNATED_INITIALIZER;

- (ACAPIOperation *)performMethod:(NSString *)method
                          apiPath:(NSString *)URLString
                            query:(NSDictionary*)query
                       parameters:(id)parameters
                       completion:(void (^)(id response, NSError *error))completion;

- (ACAPIOperation *)performMultipartWithApiPath:(NSString *)URLString
                                          query:(NSDictionary *)query
                        requestBodyConstruction:(void (^)(id<ACAPIMultipartConstructor> postData))construction
                                     completion:(void (^)(id response, NSError *error))completion;

@end
