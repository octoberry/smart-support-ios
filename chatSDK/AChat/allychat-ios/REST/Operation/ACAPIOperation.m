//
//  ACAPIOperation.m
//  ACChat
//
//  Created by Alex on 6/17/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACAPIOperation.h"

typedef void (^ac_api_progress_block_t)(NSUInteger bytes, long long totalBytes, long long totalBytesExpected);

typedef NS_ENUM(NSInteger, ACAPIOperationState) {
    ACAPIOperationReadyState       = 1,
    ACAPIOperationExecutingState   = 2,
    ACAPIOperationFinishedState    = 3,
};


static inline NSString * ACAPIKeyPathFromOperationState(ACAPIOperationState state) {
    switch (state) {
        case ACAPIOperationReadyState:
            return @"isReady";
        case ACAPIOperationExecutingState:
            return @"isExecuting";
        case ACAPIOperationFinishedState:
            return @"isFinished";
        default: return @"state";
    }
}

@interface ACAPIOperation()<NSURLConnectionDataDelegate>
@property (readwrite, nonatomic, assign) ACAPIOperationState state;
@property (readwrite, nonatomic, strong) NSURLConnection *connection;
@property (readwrite, nonatomic, strong) NSURLRequest *request;
@property (readwrite, nonatomic, strong) NSRecursiveLock *lock;
@property (readwrite, nonatomic, strong) NSURLResponse *response;
@property (readwrite, nonatomic, strong) NSError *error;
@property (readwrite, nonatomic, strong) NSMutableData *responseData;
@property (readwrite, nonatomic, copy) ac_api_progress_block_t uploadProgress;
@property (readwrite, nonatomic, copy) ac_api_progress_block_t downloadProgress;
@end

@implementation ACAPIOperation

+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"AllyChat"];
        
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

+ (NSThread *)networkRequestThread {
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_networkRequestThread start];
    });
    
    return _networkRequestThread;
}

- (instancetype)initWithRequest:(NSURLRequest *)urlRequest completion:(void (^)(NSURLResponse *response, NSData *data, NSError *error))completion {
    NSParameterAssert(urlRequest);
    
    self = [super init];
    if (!self) {
        return nil;
    }
    _state = ACAPIOperationReadyState;
    self.lock = [[NSRecursiveLock alloc] init];
    self.lock.name = @"com.ally-chat.operation.lock";
    self.request = urlRequest;
    
    [self setCompletionBlock:completion];
    
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)urlRequest {
    return [self initWithRequest:urlRequest completion:nil];
}

#pragma mark -

- (void)setState:(ACAPIOperationState)state {
    if (state <= self.state) return;
    
    [self.lock lock];
    NSString *oldStateKey = ACAPIKeyPathFromOperationState(self.state);
    NSString *newStateKey = ACAPIKeyPathFromOperationState(state);
    
    [self willChangeValueForKey:newStateKey];
    [self willChangeValueForKey:oldStateKey];
    _state = state;
    [self didChangeValueForKey:oldStateKey];
    [self didChangeValueForKey:newStateKey];
    [self.lock unlock];
}

#pragma mark -

- (void)setUploadProgressBlock:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))block {
    self.uploadProgress = block;
}
- (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))block {
    self.downloadProgress = block;
}

#pragma mark - NSOperation

- (void)setCompletionBlock:(void (^)(NSURLResponse *response, NSData *data, NSError *error))block {
    [self.lock lock];
    if (!block) {
        [super setCompletionBlock:nil];
    } else {
        __weak __typeof(self)weakSelf = self;
        [super setCompletionBlock:^ {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                block(strongSelf.response, strongSelf.responseData, strongSelf.error);
            });
        }];
    }
    [self.lock unlock];
}

- (BOOL)isReady {
    return self.state == ACAPIOperationReadyState && [super isReady];
}

- (BOOL)isExecuting {
    return self.state == ACAPIOperationExecutingState;
}

- (BOOL)isFinished {
    return self.state == ACAPIOperationFinishedState;
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)start {
    [self.lock lock];
    if ([self isCancelled]) {
        [self performSelector:@selector(cancelConnection) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO];
    } else if ([self isReady]) {
        self.state = ACAPIOperationExecutingState;
        
        [self performSelector:@selector(operationDidStart) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO];
    }
    [self.lock unlock];
}

- (void)operationDidStart {
    [self.lock lock];
    if (![self isCancelled]) {
        self.responseData = [NSMutableData dataWithCapacity: 0];
        
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        if (!self.connection) {
            self.responseData = nil;
        }
        [self.connection start];
    }
    [self.lock unlock];
}

- (void)finish {
    [self.lock lock];
    self.state = ACAPIOperationFinishedState;
    [self.lock unlock];
}

- (void)cancel {
    [self.lock lock];
    if (![self isFinished] && ![self isCancelled]) {
        [super cancel];
        
        if ([self isExecuting]) {
            [self performSelector:@selector(cancelConnection) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO];
        }
    }
    [self.lock unlock];
}

- (void)cancelConnection {
    NSDictionary *userInfo = nil;
    if ([self.request URL]) {
        userInfo = [NSDictionary dictionaryWithObject:[self.request URL] forKey:NSURLErrorFailingURLErrorKey];
    }
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];
    
    if (![self isFinished]) {
        if (self.connection) {
            [self.connection cancel];
            [self performSelector:@selector(connection:didFailWithError:) withObject:self.connection withObject:error];
        } else {
            // Accomodate race condition where `self.connection` has not yet been set before cancellation
            self.error = error;
            [self finish];
        }
    }
}

#pragma mark - NSObject

- (NSString *)description {
    [self.lock lock];
    NSString *description = [NSString stringWithFormat:@"<%@: %p, state: %@, cancelled: %@ request: %@, response: %@>", NSStringFromClass([self class]), self, ACAPIKeyPathFromOperationState(self.state), ([self isCancelled] ? @"YES" : @"NO"), self.request, self.response];
    [self.lock unlock];
    return description;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection __unused *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.uploadProgress) {
            self.uploadProgress((NSUInteger)bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        }
    });
}
- (void)connection:(NSURLConnection __unused *)connection
didReceiveResponse:(NSURLResponse *)response
{
    self.response = response;
    [self.responseData setLength:0];
}

- (void)connection:(NSURLConnection __unused *)connection
    didReceiveData:(NSData *)data
{
    NSUInteger length = [data length];
    
    [self.responseData appendData:data];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.downloadProgress) {
            self.downloadProgress(length, self.responseData.length, self.response.expectedContentLength);
        }
    });
}



- (void)connectionDidFinishLoading:(NSURLConnection __unused *)connection {
    
    self.connection = nil;
    
    [self finish];
}

- (void)connection:(NSURLConnection __unused *)connection
  didFailWithError:(NSError *)error
{
    self.error = error;
    
    self.responseData = nil;
    self.connection = nil;
    
    [self finish];
}

/**
 Support for invalid/untrusted SSL certificates.
 With defining this constant, acceptation of invalid/unknown SSL certificates will be without any warning. Use this only for debugging!
 */
#ifdef ALLOW_INVALID_SSL_CERTIFICATES
-(void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([[challenge protectionSpace] authenticationMethod] == NSURLAuthenticationMethodServerTrust) {
        [[challenge sender] useCredential:[NSURLCredential credentialForTrust:[[challenge protectionSpace] serverTrust]] forAuthenticationChallenge:challenge];
    }
}
#endif

@end
