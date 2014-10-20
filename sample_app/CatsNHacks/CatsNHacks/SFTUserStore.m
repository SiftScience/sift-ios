//
//  SFTUserStore.m
//  CatsNHacks
//
//  Created by Joey Robinson on 8/13/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import "SFTUserStore.h"

@implementation SFTUserStore

static NSString* currentUser = @"";

+(NSString*) user {
    return currentUser;
}

+(void) setUser:(NSString *)aUser {
    currentUser = [aUser copy];
}
@end
