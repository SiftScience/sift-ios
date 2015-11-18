// Copyright (c) 2015 Sift Science. All rights reserved.

#import "Sift/SFEvent.h"
#import "Sift/Sift.h"

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

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

@end
