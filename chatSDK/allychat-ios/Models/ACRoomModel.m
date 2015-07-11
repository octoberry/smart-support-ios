//
//  ACRoomModel.m
//  ACChat
//
//  Created by Alex on 6/18/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACRoomModel.h"

@implementation ACRoomModel
- (void)setDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation {
    [super setDictionaryRepresentation:dictionaryRepresentation];
    self.roomID = dictionaryRepresentation[@"id"];
    self.lastMessage = [ACMessageModel modelWithDictionary:dictionaryRepresentation[@"last_message"]];
    self.lastReadMessageID = dictionaryRepresentation[@"last_read_message_id"];
    self.firstMessageID = dictionaryRepresentation[@"first_message"];
    self.supportRoom = [dictionaryRepresentation[@"is_support"] boolValue];
    NSMutableArray *users = [NSMutableArray array];
    for (NSDictionary *d in dictionaryRepresentation[@"users"]) {
        if (d[@"id"]) {
            [users addObject:d[@"id"]];
        }
    }
    self.users = users;
}
@end
