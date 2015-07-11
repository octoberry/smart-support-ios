//
//  NSObject+MethodsDependency.m
//  TestApp
//
//  Created by Alex on 6/21/15.
//  Copyright (c) 2015 alexizh. All rights reserved.
//

#import "NSObject+MethodsDependency.h"
#import <objc/runtime.h>

@interface __MDRegisteredMethod__ : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, copy) BOOL(^condition)();
@property (nonatomic, assign) SEL selector;
@end

@implementation __MDRegisteredMethod__
@end

@interface __MDDependency__ : NSObject
@property (nonatomic, copy) void(^error)(NSError *error);
@property (nonatomic, copy) void(^success)();
@end

@implementation __MDDependency__
@end

@interface NSObject(MethodsDependency_Private)
@property (nonatomic, strong) NSMutableDictionary   *md_registered_methods;
@property (nonatomic, strong) NSMutableDictionary   *md_dependency_queue;
@property (nonatomic, strong) NSMutableSet          *md_running_methods;
@end

@implementation NSObject (MethodsDependency)
#pragma mark - 
- (void)setMd_dependency_queue:(NSMutableDictionary *)md_dependency_queue {
    objc_setAssociatedObject(self, (__bridge const void *)@"md_dependency_queue", md_dependency_queue, OBJC_ASSOCIATION_RETAIN);
}
- (NSMutableDictionary *)md_dependency_queue {
    NSMutableDictionary*dic = objc_getAssociatedObject(self, (__bridge const void *)@"md_dependency_queue");
    if (!dic) {
        dic = [NSMutableDictionary dictionary];
        self.md_dependency_queue = dic;
    }
    return dic;
}
- (void)setMd_registered_methods:(NSMutableDictionary *)md_registered_methods {
    objc_setAssociatedObject(self, (__bridge const void *)@"md_registered_methods", md_registered_methods, OBJC_ASSOCIATION_RETAIN);
}
- (NSMutableDictionary *)md_registered_methods {
    NSMutableDictionary *dic = objc_getAssociatedObject(self, (__bridge const void *)@"md_registered_methods");
    if (!dic) {
        dic = [NSMutableDictionary dictionary];
        self.md_registered_methods = dic;
    }
    return dic;
}
- (void)setMd_running_methods:(NSMutableSet *)md_running_methods {
    objc_setAssociatedObject(self, (__bridge const void *)@"md_running_methods", md_running_methods, OBJC_ASSOCIATION_RETAIN);
}
- (NSMutableSet *)md_running_methods {
    NSMutableSet *set = objc_getAssociatedObject(self, (__bridge const void *)@"md_running_methods");
    if (!set) {
        set = [NSMutableSet set];
        self.md_running_methods = set;
    }
    return set;
}

#pragma mark - actions
- (void)md_registerMethod:(NSString *)name condition:(BOOL(^)())condition selector:(SEL)selector {
    NSParameterAssert(name);
    NSAssert([self respondsToSelector:selector], @"%@ does not respond selector %@", NSStringFromClass(self.class), NSStringFromSelector(selector));
    __MDRegisteredMethod__ *method = [__MDRegisteredMethod__ new];
    method.name = name;
    method.condition = condition;
    method.selector = selector;
    self.md_registered_methods[name] = method;
    self.md_dependency_queue[name] = [NSMutableArray array];
}
- (void)md_dependencyWithName:(NSString *)name error:(void(^)(NSError* error))error success:(dispatch_block_t)success {
    NSParameterAssert(name);
    __MDRegisteredMethod__ *method = self.md_registered_methods[name];
    if (method) {
        if (method.condition && !method.condition()) {
            __MDDependency__ *dependency = [__MDDependency__ new];
            dependency.error = error;
            dependency.success = success;
            
            if (![self.md_running_methods containsObject:method.name]) {
                [self.md_dependency_queue[method.name] addObject:dependency];
                [self.md_running_methods addObject:method.name];
                
                typeof(self) self_weak = self;
                [self performSelector:method.selector withObject:^(NSError *error){
                    typeof(self_weak) self_ = self_weak;
                    //fail or success
                    for (__MDDependency__ *dep in self_.md_dependency_queue[method.name]) {
                        if (error && dep.error) { dep.error(error); }
                        else if (!error && dep.success) { dep.success(); }
                    }
                    //
                    NSLog(@"Finished registered method with name: %@", method.name);
                    
                    [self_.md_dependency_queue[method.name] removeAllObjects];
                    [self_.md_running_methods removeObject:method.name];
                }];
            } else {
                [self.md_dependency_queue[method.name] addObject:dependency];
            }
        } else {
            if (success) { success(); }
        }
    } else {
        if (success) { success(); }
    }
}
@end
