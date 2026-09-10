//
//  SiftKeychain+Testing.h
//  Sift
//
//  Created by Anton Poluboiarynov on 20.01.2025.
//  Copyright © 2025 Sift Science. All rights reserved.
//

#import "SiftKeychain.h"
@import Security;

@interface SiftKeychain ()
+ (NSString *)getStoredIFVString;
+ (NSString *)processStoredIFVAttributes:(NSDictionary *)attributes;
+ (void)storeIFVString:(NSString *)ifv;
+ (OSStatus)addIFV:(NSString *)ifv;
+ (void)migrateStoredIFV:(NSString *)ifv;
+ (void)deleteStoredIFV;
+ (NSDictionary *)ifvDeleteQuery;
+ (NSString *)vendorIFVKeychainKey;
+ (NSDictionary *)keychainQueryForIFV:(NSString *)ifv;
+ (BOOL)attributesNeedMigration:(NSDictionary *)attributes;
@end
