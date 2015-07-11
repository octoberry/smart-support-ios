//
//  ACAPIOperationManager.m
//  ACChat
//
//  Created by Alex on 6/17/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACAPIOperationManager.h"
#import "ACAPIOperation.h"
#import "ACMultipartBodyConstructor.h"



NSString *const ACAPIOperationManagerTokenExpireNotification = @"ACAPIOperationManagerTokenExpireNotification";

static id ACJSONObjectByRemovingKeysWithNullValues(id JSONObject, NSJSONReadingOptions readingOptions) {
    if ([JSONObject isKindOfClass:[NSArray class]]) {
        NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:[(NSArray *)JSONObject count]];
        for (id value in (NSArray *)JSONObject) {
            [mutableArray addObject:ACJSONObjectByRemovingKeysWithNullValues(value, readingOptions)];
        }
        
        return (readingOptions & NSJSONReadingMutableContainers) ? mutableArray : [NSArray arrayWithArray:mutableArray];
    } else if ([JSONObject isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionaryWithDictionary:JSONObject];
        for (id <NSCopying> key in [(NSDictionary *)JSONObject allKeys]) {
            id value = [(NSDictionary *)JSONObject objectForKey:key];
            if (!value || [value isEqual:[NSNull null]]) {
                [mutableDictionary removeObjectForKey:key];
            } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                [mutableDictionary setObject:ACJSONObjectByRemovingKeysWithNullValues(value, readingOptions) forKey:key];
            }
        }
        
        return (readingOptions & NSJSONReadingMutableContainers) ? mutableDictionary : [NSDictionary dictionaryWithDictionary:mutableDictionary];
    }
    
    return JSONObject;
}


@interface ACAPIOperationManager()
@property (readwrite, nonatomic, strong) NSURL *baseURL;
@property (readwrite, nonatomic, strong) NSOperationQueue *queue;
@end

@implementation ACAPIOperationManager


- (instancetype)init {
    return [self initWithBaseURL:nil];
}

- (instancetype)initWithBaseURL:(NSURL *)url {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    if ([[url path] length] > 0 && ![[url absoluteString] hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@""];
    }
    
    self.baseURL = url;
    self.queue = [NSOperationQueue new];
    
    return self;
}

#pragma mark - Request

- (NSMutableURLRequest *)requestWithURLString:(NSString *)URLString
                                        query:(NSDictionary *)query
{
    NSParameterAssert(URLString);
    
    NSString *apiURLString = URLString;
    
    if (query) {
        NSMutableString *queryString = [NSMutableString string];
        for (NSString *key in query.allKeys) {
            NSString *value = [NSString stringWithFormat:@"%@", query[key]];
            [queryString appendFormat:@"%@%@=%@", queryString.length > 0 ? @"&" : @"?", key, [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        }
        apiURLString = [NSString stringWithFormat:@"%@%@", apiURLString, queryString];
    }
    NSURL *url = [NSURL URLWithString:apiURLString relativeToURL:self.baseURL];
    
    NSParameterAssert(url);
    
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:url];
    return mutableRequest;
}


- (ACAPIOperation *)HTTPOperationWithRequest:(NSURLRequest *)request
                                  completion:(void (^)(id response, NSError *error))completion
{
    return [[ACAPIOperation alloc] initWithRequest:request completion:completion? ^(NSURLResponse *urlResponse, NSData *data, NSError *error) {
        id JSONData = nil;
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)urlResponse;
        if([[NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", nil] containsObject:httpResponse.MIMEType])
        {
            if (httpResponse.statusCode == 200) {
                JSONData = [self contentDictRepresentation:httpResponse data:data];
            }
            else
            {
                error = [self innerServerErrorsHandler:httpResponse forData:data];
            }
            
        }
        else
        {
            NSError *serializationError;
            NSDictionary *plainResponse = [[NSDictionary alloc] initWithObjectsAndKeys:@(httpResponse.statusCode),@"status", nil];
            JSONData =  (NSDictionary *)[NSJSONSerialization dataWithJSONObject:plainResponse
                                                                        options:NSJSONWritingPrettyPrinted
                                                                          error:&serializationError];
        }
        completion(JSONData, error);
    } :nil];
}



- (ACAPIOperation *)performMethod:(NSString *)method
                          apiPath:(NSString *)URLString
                            query:(NSDictionary*)query
                       parameters:(id)parameters
                       completion:(void (^)(id response, NSError *error))completion
{
    NSParameterAssert(method);
    NSParameterAssert(URLString);
    return [self performApiPath:URLString query:query requestBodyConstruction:^NSError *(NSMutableURLRequest *mutableRequest) {
        mutableRequest.HTTPMethod = method;
        
        if (parameters) {
            if (![mutableRequest valueForHTTPHeaderField:@"Content-Type"]) {
                [mutableRequest addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            }
            if ([parameters isKindOfClass:[NSDictionary class]]) {
                NSError *serializationError = nil;
                NSMutableString *body = [NSMutableString string];
                NSMutableString *queryString = [NSMutableString string];
                for (NSString *key in [parameters allKeys]) {
                    NSString *value = [NSString stringWithFormat:@"%@", [parameters objectForKey:key]];
                    [queryString appendFormat:@"%@%@=%@", queryString.length > 0 ? @"&" : @"", key, [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                }
                body = queryString;
                mutableRequest.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
                if (serializationError) {
                    return serializationError;
                }
            } else if ([parameters isKindOfClass:[NSData class]]) {
                mutableRequest.HTTPBody = parameters;
            }
        }
        return nil;
    } completion:completion];
}

- (ACAPIOperation *)performApiPath:(NSString *)URLString
                             query:(NSDictionary*)query
           requestBodyConstruction:(NSError *(^)(NSMutableURLRequest *request))construction
                        completion:(void (^)(id response, NSError *error))completion
{
    NSParameterAssert(URLString);
    NSMutableURLRequest *request = [self requestWithURLString:URLString query:query];
    if (construction) {
        NSError *error = nil;
        if ((error = construction(request))) {
            if (completion) { completion(nil,error); }
            return nil;
        }
    }
    ACAPIOperation *operation = [self HTTPOperationWithRequest:request completion:completion];
    
    [self.queue addOperation:operation];
    
    return operation;
}

- (ACAPIOperation *)performMultipartWithApiPath:(NSString *)URLString
                                          query:(NSDictionary *)query
                        requestBodyConstruction:(void (^)(id<ACAPIMultipartConstructor> postData))construction
                                     completion:(void (^)(id response, NSError *error))completion
{
    return [self performApiPath:URLString query:query requestBodyConstruction:^NSError *(NSMutableURLRequest *request) {
        request.HTTPMethod = @"POST";
        
        NSString *uniqueId = [[NSUUID UUID] UUIDString];
        NSString *boundaryString = [NSString stringWithFormat:@"AllyChat-%@", uniqueId];
        [request addValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundaryString] forHTTPHeaderField:@"Content-Type"];
        ACMultipartBodyConstructor *constructor = [[ACMultipartBodyConstructor alloc] initWithBoundary:boundaryString];
        if (construction) { construction(constructor); }
        NSData *data = [constructor generateBody];
        [request setHTTPBody:data];
        [request addValue:[NSString stringWithFormat:@"%@", @(data.length)] forHTTPHeaderField:@"Content-Length"];
        return nil;
    } completion:completion];
}




- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, baseURL: %@, operationQueue: %@>", NSStringFromClass([self class]), self, [self.baseURL absoluteString], self.queue];
}

#pragma mark - Helpers method

- (NSDictionary *)contentDictRepresentation:(NSHTTPURLResponse *)response data:(NSData *)data
{
    NSDictionary *JSONData = [NSJSONSerialization  JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    JSONData = ACJSONObjectByRemovingKeysWithNullValues(JSONData, NSJSONReadingAllowFragments);
    return JSONData;
}

-(NSError *)innerServerErrorsHandler:(NSHTTPURLResponse *)response forData:(NSData *)data
{
    NSError *error = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        if (response.statusCode == 400)
        {
            NSDictionary *errorDict = [self contentDictRepresentation:response data:data][@"error"];
            if (errorDict)
            {
                NSString *errorMessage = errorDict[@"message"];
                NSUInteger errorCode = [errorDict[@"code"] unsignedIntegerValue];
                switch (errorCode) {
                        //Missing token
                    case 1001:
                    {
                        
                    }
                        break;
                        //Invalid or expired token
                    case 1002:
                    {
                        [[NSNotificationCenter defaultCenter] postNotificationName:ACAPIOperationManagerTokenExpireNotification object:nil];
                    }
                        break;
                        //Missing auth_token
                    case 1011:
                    {
                        
                    }
                        break;
                        //Invalid or expired auth_token
                    case 1012:
                    {
                        [self.delegate externalTokenExpired];
                    }
                        break;
                        //Unknown app_id
                    case 1020:
                    {
                        
                    }
                        break;
                        
                    default:
                        break;
                }
                error = [NSError errorWithDomain:@"com.allychat" code:errorCode userInfo:@{NSLocalizedDescriptionKey:errorMessage}];
            }
            else
            {
                error = [NSError errorWithDomain:@"com.allychat" code:400 userInfo:@{NSLocalizedDescriptionKey:@"Bad request"}];
            }
        }
        else
        {
            error = [NSError errorWithDomain:@"com.allychat" code:response.statusCode userInfo:@{NSLocalizedDescriptionKey:@"Server error"}];
        }
    }
    return error;
}

@end
