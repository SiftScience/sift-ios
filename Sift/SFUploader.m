// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Private.h"

#import "SFUploader.h"

@implementation SFUploader {
    // Use serial queue as an alternative to locking.
    dispatch_queue_t _serial;
    NSURLSession *_session;
    NSMutableArray *_batches;
    int _numRejects;
    int64_t _backoffBase;
    int64_t _backoff;
    NSString *_archivePath;
    // Weak reference back to the parent.
    Sift * __weak _sift;
}

// Drop a batch if our backend has rejected it `SF_REJECT_LIMIT` times.
static const int SF_REJECT_LIMIT = 3;

static const int64_t SF_BACKOFF = NSEC_PER_SEC;  // Starting from 1 second.

- (instancetype)initWithArchivePath:(NSString *)archivePath sift:(Sift *)sift {
    return [self initWithArchivePath:archivePath sift:sift config:[NSURLSessionConfiguration defaultSessionConfiguration] backoffBase:SF_BACKOFF];
}

- (instancetype)initWithArchivePath:(NSString *)archivePath sift:(Sift *)sift config:(NSURLSessionConfiguration *)config backoffBase:(int64_t)backoffBase {
    self = [super init];
    if (self) {
        _serial = dispatch_queue_create("com.sift.SFUploader", NULL);
        _archivePath = archivePath;
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        _backoffBase = backoffBase;
        _backoff = backoffBase;
        _sift = sift;

        [self unarchive];

        // In case we have unfinished upload jobs...
        dispatch_async(_serial, ^{[self doUpload];});
    }
    return self;
}

- (void)upload:(NSArray *)events {
    dispatch_async(_serial, ^{
        SF_DEBUG(@"Batch size: %lu", (unsigned long)events.count);
        [_batches addObject:events];

        if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
            SF_DEBUG(@"App is in background");
            // Back up aggressively if we are in the background.
            [self archive];
            return;
        }

        if (_batches.count > 1) {
            SF_DEBUG(@"An upload is (probably) in progress");
            return;
        }

        Sift *sift = _sift;
        if (!sift.accountId || !sift.beaconKey || !sift.serverUrlFormat) {
            SF_DEBUG(@"Lack accountId (%@), beaconKey (%@), and/or serverUrlFormat (%@)", sift.accountId, sift.beaconKey, sift.serverUrlFormat);
            return;
        }

        [self doUpload];
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    dispatch_async(_serial, ^{
        BOOL success = NO;
        if (error) {
            SF_DEBUG(@"Could not complete upload due to %@", [error localizedDescription]);
        } else {
            NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
            SF_DEBUG(@"PUT %@ status %ld", task.response.URL, (long)statusCode);
            if (statusCode == 200) {
                [_batches removeObjectAtIndex:0];
                _numRejects = 0;
                success = YES;
            } else if (statusCode == 400) {
                _numRejects++;
                if (_numRejects >= SF_REJECT_LIMIT) {
                    SF_DEBUG(@"Drop a batch due to reject limit reached");
                    [_batches removeObjectAtIndex:0];
                    _numRejects = 0;
                }
            }
        }
        // Keep working on unfinished upload jobs.
        if (success) {
            _backoff = _backoffBase;
            [self doUpload];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, _backoff), _serial, ^{[self doUpload];});
            _backoff *= 2;
        }
    });
}

// NOTE: Unprotected access - call this from within the serial dispatch queue.
- (void)doUpload {
    if (!_batches.count || UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
        return;
    }

    Sift *sift = _sift;
    if (!sift) {
        SF_DEBUG(@"Reference to Sift object was lost");
        return;
    }

    NSURL *serverUrl = [NSURL URLWithString:[NSString stringWithFormat:sift.serverUrlFormat, sift.accountId]];
    SF_DEBUG(@"serverUrl: %@", serverUrl);
    if(!serverUrl) {
        SF_DEBUG(@"Could not construct server URL: serverUrlFormat=%@, accountId=%@", sift.serverUrlFormat, sift.accountId);
        return;
    }

    NSString *encodedBeaconKey = [[sift.beaconKey dataUsingEncoding:NSASCIIStringEncoding] base64EncodedStringWithOptions:0];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:serverUrl];
    [request setHTTPMethod:@"PUT"];
    [request setValue:[@"Basic " stringByAppendingString:encodedBeaconKey] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    SF_DEBUG(@"request: %@", request);

    NSData *body = [SFEvent listRequest:[_batches objectAtIndex:0]];
    NSURLSessionUploadTask *task = [_session uploadTaskWithRequest:request fromData:body];
    [task resume];
}

#pragma mark - NSKeyedArchiver/NSKeyedUnarchiver

static NSString * const SF_BATCHES = @"batches";
static NSString * const SF_NUM_REJECTS = @"numRejects";

- (void)archive {
    dispatch_async(_serial, ^{
        NSDictionary *archive = @{SF_BATCHES: _batches, SF_NUM_REJECTS: @(_numRejects)};
        [NSKeyedArchiver archiveRootObject:archive toFile:_archivePath];
    });
}

// NOTE: Unprotected access - call this from within the serial dispatch queue.
- (void)unarchive {
    NSDictionary *archive = [NSKeyedUnarchiver unarchiveObjectWithFile:_archivePath];
    if (archive) {
        _batches = [NSMutableArray arrayWithArray:[archive objectForKey:SF_BATCHES]];
        _numRejects = ((NSNumber *)[archive objectForKey:SF_NUM_REJECTS]).intValue;
    } else {
        _batches = [NSMutableArray new];
        _numRejects = 0;
    }
    SF_DEBUG(@"Unarchive %lu batches", (unsigned long)_batches.count);
}

@end
