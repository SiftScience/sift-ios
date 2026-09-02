// AppDelegate.h
//
// Minimal application delegate for the SiftE2ETestHost app. This app exists solely to give
// the SiftE2ETests XCTest bundle a hosting process (TEST_HOST) so it runs with a real Keychain
// access entitlement on Simulator. It has no functionality of its own.

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
