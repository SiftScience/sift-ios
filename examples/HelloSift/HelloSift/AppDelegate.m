// Copyright (c) 2015 Sift Science. All rights reserved.

#import "Sift/Sift.h"

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Configure Sift object here.

    // At minimum, you should configure these two.
    //[Sift sharedSift].accountId = ...;
    //[Sift sharedSift].beaconKey = ...;

    // In addition, if you have any queues, you should set up them here.
    //[[Sift sharedSift] addEventQueue:... config:...];

    // During integration, you may set this URL to a RequestBin or a private server to validate that your integration works.
    //[Sift sharedSift].serverUrlFormat = @"http://localhost:8080";

    return YES;
}

@end
