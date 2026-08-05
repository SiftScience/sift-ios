//
//  SiftKeychain+Testing.h
//  Sift
//
//  Created by Anton Poluboiarynov on 20.01.2025.
//  Copyright © 2025 Sift Science. All rights reserved.
//

#import "SiftKeychain.h"

@interface SiftKeychain ()
+ (NSString *)getStoredIFVString;
+ (void)storeIFVString:(NSString *)ifv;
+ (NSString *)vendorIFVKeychainKey;
+ (NSDictionary *)keychainQueryForIFV:(NSString *)ifv;
+ (BOOL)attributesNeedMigration:(NSDictionary *)attributes;
@end
