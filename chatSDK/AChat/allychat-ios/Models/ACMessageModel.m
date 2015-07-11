//
//  ACMessageModel.m
//  ACChat
//
//  Created by Alex on 6/18/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACMessageModel.h"
#import "ACBaseModel+Protected.h"

@implementation ACMessageModel
- (void)setDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation {
    [super setDictionaryRepresentation:dictionaryRepresentation];
    if (dictionaryRepresentation[@"created_at"]) {
        self.sentDate = [NSDate dateWithTimeIntervalSince1970:[dictionaryRepresentation[@"created_at"] integerValue]];
    }
    if (dictionaryRepresentation[@"file"] && ![dictionaryRepresentation[@"file"] isKindOfClass:[NSNull class]]) {
        self.fileAttachmentURL = [NSURL URLWithString:dictionaryRepresentation[@"file"]];
    }
    self.messageID = dictionaryRepresentation[@"id"];
    self.message = dictionaryRepresentation[@"message"];
    self.roomID = dictionaryRepresentation[@"room"];
    self.senderID = dictionaryRepresentation[@"sender"];
}
@end
