// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import UIKit;

#import "Sift/SiftEvent.h"
#import "Sift/Sift.h"

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController {
    CLLocationManager *_manager;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if ([Sift sharedInstance].accountId) {
        self.accountIdTextField.text = [Sift sharedInstance].accountId;
    }
    if ([Sift sharedInstance].beaconKey) {
        self.beaconKeyTextField.text = [Sift sharedInstance].beaconKey;
    }
    if ([Sift sharedInstance].userId) {
        self.userIdTextField.text = [Sift sharedInstance].userId;
    }
    if ([Sift sharedInstance].serverUrlFormat) {
        self.serverUrlFormatTextField.text = [Sift sharedInstance].serverUrlFormat;
    }

    UIDevice *device = UIDevice.currentDevice;
    device.batteryMonitoringEnabled = YES;
    [device beginGeneratingDeviceOrientationNotifications];
    device.proximityMonitoringEnabled = YES;

    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    NSLog(@"Ask for permission of location service: status=%d", status);
    if (status == kCLAuthorizationStatusNotDetermined) {
        _manager = [CLLocationManager new];
        [_manager requestAlwaysAuthorization];
    }
    [_manager startUpdatingLocation];
    [_manager startUpdatingHeading];
}

- (IBAction)handleUserIdChanged:(id)sender {
    NSString *userId = self.userIdTextField.text;
    NSLog(@"New user ID is \"%@\"", userId);
    [Sift sharedInstance].userId = userId;
}

- (IBAction)handleAccountIdChanged:(id)sender {
    [self setProperty:sender getter:@selector(accountId) setter:@selector(setAccountId:)];
}

- (IBAction)handleBeaconKeyChanged:(id)sender {
    [self setProperty:sender getter:@selector(beaconKey) setter:@selector(setBeaconKey:)];
}

- (IBAction)handleServerUrlChanged:(id)sender {
    [self setProperty:sender getter:@selector(serverUrlFormat) setter:@selector(setServerUrlFormat:)];
}

- (void)setProperty:(UITextField *)textField getter:(SEL)getter setter:(SEL)setter {
    NSString *(*getterFunc)(id, SEL) = (void *)[[Sift sharedInstance] methodForSelector:getter];
    NSString *oldValue = getterFunc([Sift sharedInstance], getter);
    NSString *newValue = textField.text;
    NSLog(@"%@: %@ -> %@", NSStringFromSelector(getter), oldValue, newValue);
    void (*setterFunc)(id, SEL, NSString*) = (void *)[[Sift sharedInstance] methodForSelector:setter];
    setterFunc([Sift sharedInstance], setter, newValue);
}
- (IBAction)collectButtonClicked:(id)sender {
    NSLog(@"Button \"Request Collect\" was clicked");
    [[Sift sharedInstance] collect];
}

- (IBAction)handleRequestUploadButtonClick:(id)sender {
    NSLog(@"Button \"Request Upload\" was clicked");
    [[Sift sharedInstance] upload:YES];
}

- (IBAction)handleEnableDisable:(UISwitch *)sender {
   if (sender.isOn == YES)
   {
       [[Sift sharedInstance] restartCollection];
       [[Sift sharedInstance] collect];
       [[Sift sharedInstance] upload:YES];
   }
    else
    {
        [[Sift sharedInstance] stopCollection];
    }
}

@end
