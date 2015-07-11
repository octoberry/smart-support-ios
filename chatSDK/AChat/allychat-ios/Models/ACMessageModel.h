//
//  ACMessageModel.h
//  ACChat
//
//  Created by Alex on 6/18/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <AChat/ACBaseModel.h>

@interface ACMessageModel : ACBaseModel

@property (nonatomic, strong) NSString  *messageID;

@property (nonatomic, strong) NSString  *senderID;
@property (nonatomic, strong) NSString  *roomID;

@property (nonatomic, strong) NSString  *message;
@property (nonatomic, strong) NSURL     *fileAttachmentURL;

@property (nonatomic, strong) NSDate    *sentDate;

@end
