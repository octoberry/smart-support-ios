//
//  NSObject+MethodsDependency.h
//  TestApp
//
//  Created by Alex on 6/21/15.
//  Copyright (c) 2015 alexizh. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef BOOL(^MDRegisteredMethodBlock)(NSError *error);

@interface NSObject (MethodsDependency)
//selector should has one argument = MDRegisteredMethodBlock. And call this block when all operations completed
- (void)md_dependencyWithName:(NSString *)name error:(void(^)(NSError* error))error success:(dispatch_block_t)success;
- (void)md_registerMethod:(NSString *)name condition:(BOOL(^)())condition selector:(SEL)selector;
@end
