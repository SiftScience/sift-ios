// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

NSURLSessionConfiguration *SFMakeStubConfig(void);

typedef void (^CompletionHandlerType)(void);

@interface SFHttpStub : NSObject

+ (SFHttpStub *)sharedInstance;

@property NSMutableArray<NSNumber *> *stubbedStatusCodes;

@property NSMutableArray<NSURLRequest *> *capturedRequests;

@property (nonatomic, copy) CompletionHandlerType completionHandler;

@end