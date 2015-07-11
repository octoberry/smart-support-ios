//
//  ACUserInfoModel.h
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACUserModel.h"

/**
 * Represents information about current user
 *
 */

@interface ACUserInfoModel : NSObject

@property (nonatomic, strong) ACUserModel           *user;

@property (nonatomic, strong) NSArray               *rooms;

- (instancetype)initWithAlias:(NSString *)alias NS_DESIGNATED_INITIALIZER;

@end
