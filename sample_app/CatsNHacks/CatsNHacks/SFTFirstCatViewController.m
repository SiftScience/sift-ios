//
//  SFTFirstCatViewController.m
//  CatsNHacks
//
//  Created by Joey Robinson on 8/13/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import "SFTFirstCatViewController.h"
#import "SFTUserStore.h"
#import "SFTSiftDeviceInfo.h"
#import "SFTApiKeyHolder.h"

@interface SFTFirstCatViewController ()
@property NSString* baseTitle;
@end

@implementation SFTFirstCatViewController

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
        // Custom initialization
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
    [[[SFTSiftDeviceInfo alloc] initWithUser:[SFTUserStore user] apiKey:API_KEY] updateInfo];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
