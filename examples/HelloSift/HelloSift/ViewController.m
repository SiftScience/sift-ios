// Copyright (c) 2015 Sift Science. All rights reserved.

#import "Sift/SFEvent.h"
#import "Sift/Sift.h"

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if ([Sift sharedSift].accountId) {
        self.accountIdTextField.text = [Sift sharedSift].accountId;
    }
    if ([Sift sharedSift].beaconKey) {
        self.beaconKeyTextField.text = [Sift sharedSift].beaconKey;
    }
    if ([Sift sharedSift].serverUrlFormat) {
        self.serverUrlFormatTextField.text = [Sift sharedSift].serverUrlFormat;
    }
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
    NSString *oldValue = [[Sift sharedSift] performSelector:getter];
    NSString *newValue = textField.text;
    NSLog(@"%@: %@ -> %@", NSStringFromSelector(getter), oldValue, newValue);
    [[Sift sharedSift] performSelector:setter withObject:newValue];
}

- (IBAction)handleEnqueueEventButtonClick:(id)sender {
    NSLog(@"Button \"Enqueue Event\" was clicked");

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

    NSLog(@"userId: \"%@\"", self.userIdTextField.text);
    NSString *userId = self.userIdTextField.text;
    if ([@"" isEqualToString:userId]) {
        userId = nil;
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

    [[Sift sharedSift] appendEvent:[SFEvent eventWithPath:path mobileEventType:mobileEventType userId:userId fields:fields]];
}

- (IBAction)handleRequestUploadButtonClick:(id)sender {
    NSLog(@"Button \"Request Upload\" was clicked");
    [[Sift sharedSift] upload];
}

- (IBAction)handleForceUploadButtonClick:(id)sender {
    NSLog(@"Button \"Force Upload\" was clicked");
    [[Sift sharedSift] upload:YES];
}

- (IBAction)handleFlushEventsButtonClick:(id)sender {
    NSLog(@"Button \"Flush Events\" was clicked");
    [[Sift sharedSift] flush];
}

- (IBAction)handleDeleteEverything:(id)sender {
    NSLog(@"Button \"Delete EVERYTHING\" was clicked");
    [[Sift sharedSift] removeData];
}

@end
