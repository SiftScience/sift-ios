// AppDelegate.m
//
// Minimal application delegate for the SiftE2ETestHost app. This app exists solely to give
// the SiftE2ETests XCTest bundle a hosting process (TEST_HOST) so it runs with a real Keychain
// access entitlement on Simulator. It has no functionality of its own.

#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UIViewController alloc] init];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
