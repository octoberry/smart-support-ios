//
//  ACBaseModel+Protected.h
//  AChat
//
//  Created by Alex on 6/22/15.
//  Copyright (c) 2015 octoberry. All rights reserved.
//

#import <AChat/AChat.h>

@interface ACBaseModel ()
- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;
+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary;
- (void)setDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;
- (BOOL)validateDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;
@property (nonatomic, readonly) NSMutableDictionary          *mutableDictionaryRepresentation;
@end
