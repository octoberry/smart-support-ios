//
//  ACAPIOperation.h
//  ACChat
//
//  Created by Alex on 6/17/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ACAPIOperation : NSOperation
@property (nonatomic, readonly) NSURLRequest *request;
- (void)setUploadProgressBlock:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))block;
- (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))block;
- (void)setCompletionBlock:(void (^)(NSURLResponse *response, NSData *data, NSError *error))completionBlock;

- (instancetype)initWithRequest:(NSURLRequest *)urlRequest;
- (instancetype)initWithRequest:(NSURLRequest *)urlRequest completion:(void (^)(NSURLResponse *response, NSData *data, NSError *error))completion NS_DESIGNATED_INITIALIZER;

@end
