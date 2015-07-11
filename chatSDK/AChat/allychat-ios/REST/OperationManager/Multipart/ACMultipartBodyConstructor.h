//
//  ACMultipartBodyConstructor.h
//  ACChat
//
//  Created by Alex on 6/18/15.
//  Copyright (c) 2015 Octoberry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACAPIOperationManager.h"

@interface ACMultipartBodyConstructor : NSObject<ACAPIMultipartConstructor>

@property (nonatomic, readonly) NSString *boundary;

- (instancetype)initWithBoundary:(NSString *)boundary NS_DESIGNATED_INITIALIZER;

- (NSData *)generateBody;

@end
