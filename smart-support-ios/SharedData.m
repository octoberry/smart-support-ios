//
//  SharedData.m
//  ACChat
//
//  Created by Alex on 6/18/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "SharedData.h"

@implementation SharedData
+ (instancetype)sharedData {
    static dispatch_once_t predicate;
    static id sharedInstance = nil;
    dispatch_once(&predicate, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}
@end
