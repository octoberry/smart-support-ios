//
//  ACSocketConnection.h
//  ACChat
//
//  Created by Andrew Kopanev on 6/16/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import "ACConnection.h"

@interface ACSocketConnection : ACConnection

- (instancetype)initWithSocketHost:(NSString *)host NS_DESIGNATED_INITIALIZER;

@end
