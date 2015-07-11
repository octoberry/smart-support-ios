//
//  ACMultipartBodyConstructor.m
//  ACChat
//
//  Created by Alex on 6/18/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACMultipartBodyConstructor.h"

@interface ACMultipartBodyConstructor()
@property (nonatomic, strong) NSMutableArray *parts;
@end

@implementation ACMultipartBodyConstructor
- (instancetype)initWithBoundary:(NSString *)boundary {
    if (self = [super init]) {
        _boundary = boundary;
        _parts = [NSMutableArray array];
    }
    return self;
}


- (void)appendPartWithFile:(NSData *)file
                      name:(NSString *)name
                  fileName:(NSString *)fileName
                  mimeType:(NSString *)mimeType
{
    NSParameterAssert(name);
    NSParameterAssert(fileName);
    NSParameterAssert(mimeType);
    
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:mimeType forKey:@"Content-Type"];
    
    NSMutableDictionary *dic = [@{@"headers":mutableHeaders} mutableCopy];
    if (file) {
        dic[@"data"] = file;
    }
    [self.parts addObject:dic];
}

- (void)appendPartWithData:(NSData *)data
                      name:(NSString *)name
{
    NSParameterAssert(name);
    
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"", name] forKey:@"Content-Disposition"];
    
    NSMutableDictionary *dic = [@{@"headers":mutableHeaders} mutableCopy];
    if (data) {
        dic[@"data"] = data;
    }
    [self.parts addObject:dic];
}


- (NSData *)generateBody
{    
    NSMutableData *postData = [NSMutableData data];
    NSData *boundaryData = [[NSString stringWithFormat:@"%@", self.boundary] dataUsingEncoding:NSUTF8StringEncoding];
    [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    for (NSDictionary *dic in self.parts) {
        [postData appendData:[@"--" dataUsingEncoding:NSUTF8StringEncoding]];
        [postData appendData:boundaryData];
        [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        NSDictionary *headers = dic[@"headers"];
        for (NSString *key in headers.allKeys) {
            [postData appendData:[[NSString stringWithFormat:@"%@: %@", key, headers[key]] dataUsingEncoding:NSUTF8StringEncoding]];
            [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        NSData *data = dic[@"data"];
        if (data) {
            [postData appendData:data];
            [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
        
    }
    [postData appendData:[@"--" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:boundaryData];
    [postData appendData:[@"--" dataUsingEncoding:NSUTF8StringEncoding]];
    
    return postData;
}
@end
