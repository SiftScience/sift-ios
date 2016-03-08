// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;

#import "Sift/SFEvent.h"
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
    if ([Sift sharedInstance].serverUrlFormat) {
        self.serverUrlFormatTextField.text = [Sift sharedInstance].serverUrlFormat;
    }

    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    NSLog(@"Ask for permission of location service: status=%d", status);
    if (status == kCLAuthorizationStatusNotDetermined) {
        _manager = [CLLocationManager new];
        [_manager requestAlwaysAuthorization];
    }
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

- (IBAction)handleEnqueueEventButtonClick:(id)sender {
    NSLog(@"Button \"Enqueue Event\" was clicked");
    NSString *userId = self.userIdTextField.text;
    if (!userId.length) {
        NSLog(@"user ID is _NOT_ optional");
        return;
    }
    NSLog(@"userId: \"%@\"", userId);

    NSLog(@"path: \"%@\"", self.pathTextField.text);
    NSString *path = self.pathTextField.text;
    if ([@"" isEqualToString:path]) {
        path = nil;
    }

    NSLog(@"mobileEventType: \"%@\"", self.typeTextField.text);
    NSString *mobileEventType = self.typeTextField.text;
    if ([@"" isEqualToString:mobileEventType]) {
        mobileEventType = nil;
    }

    NSLog(@"fields: \"%@\"", self.fieldsTextField.text);
    NSDictionary *fields = nil;
    if (![@"" isEqualToString:self.fieldsTextField.text]) {
        NSData *data = [self.fieldsTextField.text dataUsingEncoding:NSASCIIStringEncoding];
        NSError *error;
        fields = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!fields) {
            NSLog(@"Could not decode JSON string due to %@", [error localizedDescription]);
        }
    }

    [[Sift sharedInstance] appendEvent:[SFEvent eventWithType:mobileEventType path:path fields:fields] withLocation:YES];
}

- (IBAction)handleRequestUploadButtonClick:(id)sender {
    NSLog(@"Button \"Request Upload\" was clicked");
    [[Sift sharedInstance] upload:YES];
}

@end
