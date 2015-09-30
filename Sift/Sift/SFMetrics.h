// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#define SF_METRICS_COUNTERS(BIN_OP) \
    /* SFEventFile counters */ \
    SF_METRICS_MAKE(EventFileDeserializationError) BIN_OP \
    SF_METRICS_MAKE(EventFileSerializationError) BIN_OP \
    SF_METRICS_MAKE(EventFileDataSizeLimitExceededError) BIN_OP \
    SF_METRICS_MAKE(EventFileCorruptionError) BIN_OP \
    SF_METRICS_MAKE(EventFileWriteError) BIN_OP \
    /* SFEventFileManager counters */ \
    SF_METRICS_MAKE(EventFileManagerDirCreationError) BIN_OP \
    SF_METRICS_MAKE(EventFileManagerDirRemovalError) BIN_OP \
    /* SFEventFileStore counters */ \
    SF_METRICS_MAKE(EventFileStoreDirCreationError) BIN_OP \
    SF_METRICS_MAKE(EventFileStoreDirListingError) BIN_OP \
    SF_METRICS_MAKE(EventFileStoreDirRemovalError) BIN_OP \
    SF_METRICS_MAKE(EventFileStoreFileCreationError) BIN_OP \
    SF_METRICS_MAKE(EventFileStoreFileOpenError) BIN_OP \
    SF_METRICS_MAKE(EventFileStoreFileRemovalError) BIN_OP \
    SF_METRICS_MAKE(EventFileStoreFileRotationSuccess) BIN_OP \
    SF_METRICS_MAKE(EventFileStoreFileRotationError) BIN_OP \
    /* SFEventFileUploader counters */ \
    SF_METRICS_MAKE(EventFileUploaderUpload) BIN_OP \
    SF_METRICS_MAKE(EventFileUploaderUploadSuccess) BIN_OP \
    SF_METRICS_MAKE(EventFileUploaderNetworkError) BIN_OP \
    SF_METRICS_MAKE(EventFileUploaderFileRemovalError) BIN_OP \
    /* SFEventQueue counters */ \
    SF_METRICS_MAKE(EventQueueAppend) BIN_OP \
    SF_METRICS_MAKE(EventQueueNumEventsDropped) BIN_OP \
    SF_METRICS_MAKE(EventQueueFileAttributesRetrievalError) BIN_OP \
    SF_METRICS_MAKE(EventQueueFutureFileModificationDate)

#define SF_METRICS_METERS(BIN_OP) \
    /* SFEventFile meters */ \
    SF_METRICS_MAKE(EventFileEventDataSize) BIN_OP \
    /* SFEventFileManager meters */ \
    SF_METRICS_MAKE(EventFileManagerNumEventStores)

#define SF_COMMA ,

typedef NS_ENUM(NSInteger, SFMetricsKey) {
#define SF_METRICS_MAKE(name) SFMetricsKey ## name
    SF_METRICS_COUNTERS(SF_COMMA),
    SF_METRICS_METERS(SF_COMMA),
#undef SF_METRICS_MAKE
    SFMetricsNumMetrics,
};

struct _SFMetricsMeter {
    double sum;
    double sumsq;
    NSInteger count;
};

typedef struct _SFMetricsMeter SFMetricsMeter;

NSString *SFMetricsMetricName(SFMetricsKey key);

@interface SFMetrics : NSObject

+ (instancetype)sharedInstance;

- (void)count:(SFMetricsKey)counterKey;

- (void)count:(SFMetricsKey)counterKey value:(NSInteger)value;

- (void)measure:(SFMetricsKey)meterKey value:(double)value;

- (void)enumerateCountersUsingBlock:(void (^)(SFMetricsKey key, NSInteger count))block;

- (void)enumerateMetersUsingBlock:(void (^)(SFMetricsKey key, const SFMetricsMeter *meter))block;

- (void)reset;

@end
