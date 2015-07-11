//
//  ACUserModel.m
//  ACChat
//
//  Created by Alex on 6/18/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACUserModel.h"
#import "ACBaseModel+Protected.h"

@implementation ACUserModel
- (void)setDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation {
    [super setDictionaryRepresentation:dictionaryRepresentation];
    self.userID = dictionaryRepresentation[@"id"];
    self.avatarURL = [NSURL URLWithString:dictionaryRepresentation[@"avatar_url"]];
    self.alias = dictionaryRepresentation[@"alias"];
    self.name = dictionaryRepresentation[@"name"];
}
@end
