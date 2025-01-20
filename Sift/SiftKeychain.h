//
//  SiftKeychain.h
//  Sift
//
//  Created by Anton Poluboiarynov on 20.01.2025.
//  Copyright © 2025 Sift Science. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SiftKeychain : NSObject
+ (NSString *)processDeviceIFV:(NSString *)ifv;
@end
