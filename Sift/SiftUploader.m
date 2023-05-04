// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "NSData+GZIP.h"
#import "SiftDebug.h"
#import "SiftEvent.h"
#import "SiftEvent+Private.h"
#import "TaskManager.h"

#import "SiftUploader.h"

@implementation SiftUploader {
    TaskManager *_taskManager;
    // Use serial queue as an alternative to locking.
    dispatch_queue_t _serial;
    dispatch_source_t _source;
    NSURLSession *_session;
    NSURLSessionUploadTask *_uploadTask;
    NSMutableData *_responseBody;
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

static const int64_t SF_BACKOFF = NSEC_PER_SEC * 5;  // Starting from 5 seconds.

// Periodically check if we have unfinished batches.
static const int64_t SF_CHECK_UPLOAD_PERIOD = 60 * NSEC_PER_SEC;
static const int64_t SF_CHECK_UPLOAD_LEEWAY = 5 * NSEC_PER_SEC;

- (instancetype)initWithArchivePath:(NSString *)archivePath sift:(Sift *)sift {
    return [self initWithArchivePath:archivePath sift:sift config:[NSURLSessionConfiguration defaultSessionConfiguration] backoffBase:SF_BACKOFF];
}

- (instancetype)initWithArchivePath:(NSString *)archivePath sift:(Sift *)sift config:(NSURLSessionConfiguration *)config backoffBase:(int64_t)backoffBase {
    self = [super init];
    if (self) {
        _taskManager = [[TaskManager alloc] init];
        _serial = dispatch_queue_create("com.sift.SFUploader", DISPATCH_QUEUE_SERIAL);
        _archivePath = archivePath;
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        _uploadTask = nil;
        _backoffBase = backoffBase;
        _backoff = backoffBase;
        _sift = sift;

        [self unarchive];

        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _serial);
        dispatch_source_set_timer(_source, dispatch_time(DISPATCH_TIME_NOW, 0), SF_CHECK_UPLOAD_PERIOD, SF_CHECK_UPLOAD_LEEWAY);
        SiftUploader * __weak weakSelf = self;
        dispatch_source_set_event_handler(_source, ^{[weakSelf doUpload];});
        dispatch_resume(_source);
    }
    return self;
}

- (void)upload:(NSArray *)events {
    [_taskManager submitWithTask:^{
        SF_DEBUG(@"Batch size: %lu", (unsigned long)events.count);
        [self->_batches addObject:events];
        
        [self->_taskManager submitWithTask:^{
            if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
                // Back up aggressively if we are in the background.
                [self->_taskManager submitWithTask:^{
                    [self archive];
                } queue:self->_serial];
            }
            [self->_taskManager submitWithTask:^{
                [self doUpload];
            } queue:self->_serial];
        } queue:dispatch_get_main_queue()];
    } queue:_serial];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self->_taskManager submitWithTask:^{
        [self->_responseBody appendData:data];
    } queue:self->_serial];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self->_taskManager submitWithTask:^{
        NSData *responseBody = self->_responseBody;
        self->_uploadTask = nil;
        self->_responseBody = nil;

        BOOL success = NO;
        if (error) {
            SF_IMPORTANT(@"Could not complete upload due to %@", [error localizedDescription]);
        } else {
            NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
            SF_DEBUG(@"PUT %@ status %ld", task.response.URL, (long)statusCode);
            if (statusCode != 200) {
                SF_IMPORTANT(@"Error uploading events to \"%@\" (HTTP status code %ld)",
                             task.response.URL, (long)statusCode);
                if (responseBody) {
                    id response = [NSJSONSerialization JSONObjectWithData:responseBody options:0 error:nil];
                    if (response) {
                        SF_IMPORTANT(@"Server response: %@", response);
                    }
                }
            }
            if (statusCode == 200) {
                [self->_batches removeObjectAtIndex:0];
                self->_numRejects = 0;
                success = YES;
            } else if (statusCode == 400) {
                self->_numRejects = SF_REJECT_LIMIT;
            } else {
                self->_numRejects++;
            }
        }
        
        if (self->_numRejects >= SF_REJECT_LIMIT) {
            NSLog(@"Drop a batch due to reject limit reached");
            [self->_batches removeObjectAtIndex:0];
            self->_numRejects = 0;
            self->_backoff = self->_backoffBase;
        }

        // Keep working on unfinished upload jobs.
        if (success) {
            self->_backoff = self->_backoffBase;
            [self doUpload];
        } else {
            [self->_taskManager scheduleWithTask:^{
                [self doUpload];
            } queue:self->_serial delay:self->_backoff];
            self->_backoff *= 2;
        }
    } queue:self->_serial];
}

- (void)doUpload {
    // Query the applicationState on the main thread, then proceed on the serial dispatch queue
    [self->_taskManager submitWithTask:^{
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
            SF_DEBUG(@"App is in background");
            return;
        }
        
        [self->_taskManager submitWithTask:^{
            if (self->_uploadTask) {
                SF_DEBUG(@"An upload is in progress");
                return;
            }
            if (!self->_batches.count) {
                SF_DEBUG(@"No batches to upload");
                return;
            }
            
            Sift *sift = self->_sift;
            if (!sift) {
                SF_DEBUG(@"Reference to Sift object was lost");
                return;
            }
            
            if (!sift.accountId.length || !sift.beaconKey.length || !sift.serverUrlFormat.length) {
                SF_DEBUG(@"Lack accountId (%@), beaconKey (%@), and/or serverUrlFormat (%@)", sift.accountId, sift.beaconKey, sift.serverUrlFormat);
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
            [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
            SF_DEBUG(@"request: %@", request);
            
            self->_responseBody = [NSMutableData new];
            
            if (self->_batches && self->_batches.count && [self->_batches objectAtIndex:0]) {
                NSData *body = [[SiftEvent listRequest:[self->_batches objectAtIndex:0]] gzippedData];
                self->_uploadTask = [self->_session uploadTaskWithRequest:request fromData:body];
                [self->_uploadTask resume];
                SF_IMPORTANT(@"Upload a batch of %ld events to server", (unsigned long)[[_batches objectAtIndex:0] count]);
            }
        } queue:self->_serial];
    } queue:dispatch_get_main_queue()];
}

#pragma mark - NSKeyedArchiver/NSKeyedUnarchiver

static NSString * const SF_BATCHES = @"batches";
static NSString * const SF_NUM_REJECTS = @"numRejects";

- (void)archive {
    [self->_taskManager submitWithTask:^{
        NSDictionary *archive = @{SF_BATCHES: self->_batches, SF_NUM_REJECTS: @(self->_numRejects)};
   
        NSData* data = [NSKeyedArchiver archivedDataWithRootObject: archive requiringSecureCoding:NO error:nil];
        [data writeToFile:self->_archivePath options:NSDataWritingAtomic error:nil];

    } queue:_serial];
}

// NOTE: Unprotected access - call this from within the serial dispatch queue.
- (void)unarchive {
    NSDictionary *archive;
    NSData *newData = [NSData dataWithContentsOfFile:_archivePath];
    NSError *error;
   
    NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:newData error:&error];
    unarchiver.requiresSecureCoding = NO;
    archive = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:&error];
    SF_DEBUG(@"error unarchiving data: %@", error.localizedDescription);

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
