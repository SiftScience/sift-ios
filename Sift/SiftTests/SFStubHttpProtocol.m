// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFStubHttpProtocol.h"

NSMutableArray *SFCapturedRequests(void) {
    static NSMutableArray *requests;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        requests = [NSMutableArray new];
    });
    return requests;
}

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
    [SFCapturedRequests() addObject:self.request];
    NSLog(@"XXX YYY %@ %@", self.request, self.request.HTTPBody);

    // Always return 200 for now...
    NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {
    // Nothing yet...
}

@end