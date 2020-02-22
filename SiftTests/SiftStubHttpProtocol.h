// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SiftCompatibility.h"

NSURLSessionConfiguration *SFMakeStubConfig(void);

typedef void (^CompletionHandlerType)(void);

@interface SFHttpStub : NSObject

+ (SFHttpStub *)sharedInstance;

@property SF_GENERICS(NSMutableArray, NSNumber *) *stubbedStatusCodes;

@property SF_GENERICS(NSMutableArray, NSURLRequest *) *capturedRequests;

@property (nonatomic, copy) CompletionHandlerType completionHandler;

@end
