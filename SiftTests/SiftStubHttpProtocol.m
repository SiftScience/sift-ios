// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SiftStubHttpProtocol.h"

@implementation SFHttpStub

+ (SFHttpStub *)sharedInstance {
    static SFHttpStub *stub;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        stub = [SFHttpStub new];
    });
    return stub;
}

- (instancetype) init {
    self = [super init];
    if (self) {
        _stubbedStatusCodes = [NSMutableArray new];
        _capturedRequests = [NSMutableArray new];
        _completionHandler = nil;
    }
    return self;
}

@end

@interface SFStubHttpProtocol : NSURLProtocol
@end

NSURLSessionConfiguration *SFMakeStubConfig(void) {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.protocolClasses = [config.protocolClasses arrayByAddingObject:[SFStubHttpProtocol class]];
    return config;
}

@implementation SFStubHttpProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return [[[request URL] scheme] isEqualToString:@"mock+https"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [[a URL] isEqual:[b URL]];
}

- (void)startLoading {
    SFHttpStub *stub = [SFHttpStub sharedInstance];
    [stub.capturedRequests addObject:self.request];

    int statusCode = 500;
    if (stub.stubbedStatusCodes.count) {
        statusCode = ((NSNumber *)[stub.stubbedStatusCodes objectAtIndex:0]).intValue;
        [stub.stubbedStatusCodes removeObjectAtIndex:0];
    }

    // Status code 1 hardcoded for network errors.
    if (statusCode == 1) {
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:nil];
        [self.client URLProtocol:self didFailWithError:error];
        [self.client URLProtocolDidFinishLoading:self];
    } else {
        NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:nil];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
        [self.client URLProtocolDidFinishLoading:self];
    }
    if (!stub.stubbedStatusCodes.count) {
        stub.completionHandler();
    }
}

- (void)stopLoading {
    // Nothing yet...
}

@end
