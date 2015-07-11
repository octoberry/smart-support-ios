//
//  ACBaseModel.m
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACBaseModel.h"

@implementation ACBaseModel

+ (instancetype)modelWithDictionary:(NSDictionary *)dictionary {
    return [[self alloc] initWithDictionary:dictionary];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ([self validateDictionaryRepresentation:dictionary] && (self = [super init])) {
        [self setDictionaryRepresentation:dictionary];
        return self;
    } else {
        return nil;
    }
}

- (instancetype)init {
    self = [self initWithDictionary:nil];
    return self;
}

- (BOOL)validateDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation {
    return [dictionaryRepresentation isKindOfClass:[NSDictionary class]];
}

- (void)setDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation {
}

- (NSMutableDictionary *)mutableDictionaryRepresentation {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    return dictionary;
}

@end
