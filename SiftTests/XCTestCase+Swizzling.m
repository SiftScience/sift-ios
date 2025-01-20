//
//  XCTestCase+Swizzling.m
//  SiftTests
//
//  Created by Anton Poluboiarynov on 20.01.2025.
//  Copyright © 2025 Sift Science. All rights reserved.
//

#import "XCTestCase+Swizzling.h"
@import Security;
@import XCTest;

@implementation XCTestCase (Swizzling)

- (void)swizzleMethod:(Method)originalMethod withMethod:(Method)swizzledMethod {
    IMP m1_imp = method_getImplementation(originalMethod);
    IMP m2_imp = method_getImplementation(swizzledMethod);
    method_setImplementation(originalMethod, m2_imp);
    method_setImplementation(swizzledMethod, m1_imp);
}

@end
