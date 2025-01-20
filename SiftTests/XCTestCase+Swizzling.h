//
//  XCTestCase (Swizzling).h
//  SiftTests
//
//  Created by Anton Poluboiarynov on 20.01.2025.
//  Copyright © 2025 Sift Science. All rights reserved.
//

#import <objc/runtime.h>
@import Security;
@import XCTest;

@interface XCTestCase (Swizzling)
- (void) swizzleMethod:(Method)originalMethod withMethod:(Method)swizzledMethod;
@end

