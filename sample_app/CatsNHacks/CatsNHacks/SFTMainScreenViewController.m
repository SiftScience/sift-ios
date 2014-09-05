//
//  SFTMainScreenViewController.m
//  CatsNHacks
//
//  Created by Joey Robinson on 8/13/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import "SFTMainScreenViewController.h"
#import "SFTUserStore.h"
#import "SFTSiftDeviceInfo.h"
#import "SFTApiKeyHolder.h"
#import <CoreLocation/CoreLocation.h>

@interface SFTMainScreenViewController ()

@property NSString* baseTitle;

@end

@implementation SFTMainScreenViewController

- (void)updateTitle {
    NSString* text = [SFTUserStore user];
    if ([text length] > 0) {
        [self setTitle: [NSString stringWithFormat:@"%@: %@", self.baseTitle, text]];
    } else {
        [self setTitle:self.baseTitle];
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // customer initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.baseTitle = [[self navigationItem] title];
}

- (void)viewDidAppear: (BOOL) animated
{
    [super viewDidAppear:animated];
    [self updateTitle];
    CLLocationManager* manager = [CLLocationManager new];
    [manager startUpdatingLocation];
    CLLocation* location = [manager location];
    [[[SFTSiftDeviceInfo alloc] initWithUser:[SFTUserStore user] apiKey:API_KEY] updateInfo];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)updateUser:(id)sender {
    NSString* text = [self.userInputField text];
    [self.userInputField setText:@""];
    [SFTUserStore setUser: text];
    if ([text length] > 0) {
        [self.catButton1 setEnabled:YES];
        [self.catButton1 setAlpha:1];
        [self.catButton2 setEnabled:YES];
        [self.catButton2 setAlpha:1];
    }
    [self updateTitle];
}

@end
