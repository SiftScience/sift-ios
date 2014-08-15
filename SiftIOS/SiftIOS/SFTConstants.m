//
//  SFTConstants.m
//  SiftIOS
//
//  Created by Joey Robinson on 8/14/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import "SFTConstants.h"

int const SIFT_SDK_VERSION = 0;

int const SFTDEBUG = 1;

NSString* const SIFT_STATE_PREFIX = @"sft_user_saved_state:";

NSString* const API_ENDPOINT =  @"https://experiment.m.api.siftscience.com/mobile";

NSString* const IOS_EVENT =  @"$ios_device_info";

int const RESPONSE_SUCCESS = 200;

long const RETRY_FREQUENCY = 60; // 1 minute
long const MAX_RETRIES = (24 * 60 * 60) / RETRY_FREQUENCY;
int const POST_TIMEOUT = 10; // 10 seconds

long const STATE_EXPIRATION_TIME = 7 * 24 * 60 * 60 * 1000;

NSString* const USER_ID_PATTERN = @"[\\=\\+\\-\\._@:&^%!$A-Za-z0-9]+";