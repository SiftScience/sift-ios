// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileUploader.h"
#import "SFEventFileUploader+Internal.h"

#import "SFStubHttpProtocol.h"

@interface SFStubHttpProtocol : NSURLProtocol
@end

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
    // Always return 200 for now...
    NSURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {
    // Nothing yet...
}

@end

SFEventFileUploader *SFStubHttpProtocolMakeUploader(NSOperationQueue *queue, SFEventFileManager *manager, NSString *rootDirPath) {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.protocolClasses = [config.protocolClasses arrayByAddingObject:[SFStubHttpProtocol class]];

    NSString *serverUrl = @"mock+https://127.0.0.1/";

    NSString *taskFilePath = [rootDirPath stringByAppendingPathComponent:@"tasks"];

    return [[SFEventFileUploader alloc] initWithQueue:queue manager:manager config:config serverUrl:serverUrl taskFilePath:taskFilePath];
}
