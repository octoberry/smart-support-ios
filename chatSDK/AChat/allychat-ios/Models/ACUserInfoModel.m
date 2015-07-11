//
//  ACUserInfoModel.m
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACUserInfoModel.h"

@implementation ACUserInfoModel

- (instancetype)initWithAlias:(NSString *)alias andName:(NSString *)name {
    if (self = [super init]) {
        _user = [ACUserModel new];
        _user.alias = alias;
        _user.name = name;
    }
    return self;
}

@end
