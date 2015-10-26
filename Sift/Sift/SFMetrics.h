// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#define SF_METRICS_COUNTERS(BIN_OP) \
    /* SFEvent counters */ \
    SF_METRICS_MAKE(EventWriteError) BIN_OP \
    /* SFQueue counters */ \
    SF_METRICS_MAKE(QueueAppend) BIN_OP \
    SF_METRICS_MAKE(QueueNumEventsDropped) BIN_OP \
    SF_METRICS_MAKE(QueueFileAttributesRetrievalError) BIN_OP \
    SF_METRICS_MAKE(QueueFutureFileModificationDate) BIN_OP \
    /* SFQueueDirs counters */ \
    SF_METRICS_MAKE(QueueDirsDirCreationError) BIN_OP \
    SF_METRICS_MAKE(QueueDirsDirListingError) BIN_OP \
    SF_METRICS_MAKE(QueueDirsDirRemovalError) BIN_OP \
    /* SFRecordIo counters */ \
    SF_METRICS_MAKE(RecordIoDeserializationError) BIN_OP \
    SF_METRICS_MAKE(RecordIoSerializationError) BIN_OP \
    SF_METRICS_MAKE(RecordIoDataSizeLimitExceededError) BIN_OP \
    SF_METRICS_MAKE(RecordIoCorruptionError) BIN_OP \
    SF_METRICS_MAKE(RecordIoWriteError) BIN_OP \
    /* SFRotatedFiles counters */ \
    SF_METRICS_MAKE(RotatedFilesDirCreationError) BIN_OP \
    SF_METRICS_MAKE(RotatedFilesDirListingError) BIN_OP \
    SF_METRICS_MAKE(RotatedFilesDirRemovalError) BIN_OP \
    SF_METRICS_MAKE(RotatedFilesFileCreationError) BIN_OP \
    SF_METRICS_MAKE(RotatedFilesFileOpenError) BIN_OP \
    SF_METRICS_MAKE(RotatedFilesFileRemovalError) BIN_OP \
    SF_METRICS_MAKE(RotatedFilesFileRotationSuccess) BIN_OP \
    SF_METRICS_MAKE(RotatedFilesFileRotationError) BIN_OP \
    /* SFUploader counters */ \
    SF_METRICS_MAKE(UploaderUpload) BIN_OP \
    SF_METRICS_MAKE(UploaderUploadSuccess) BIN_OP \
    SF_METRICS_MAKE(UploaderNetworkError) BIN_OP \
    SF_METRICS_MAKE(UploaderFileRemovalError)

#define SF_METRICS_METERS(BIN_OP) \
    /* SFQueueDirs meters */ \
    SF_METRICS_MAKE(QueueDirsNumDirs) BIN_OP \
    /* SFRecordIo meters */ \
    SF_METRICS_MAKE(RecordIoDataSize)

#define SF_COMMA ,

typedef NS_ENUM(NSInteger, SFMetricsKey) {
#define SF_METRICS_MAKE(name) SFMetricsKey ## name
    SF_METRICS_COUNTERS(SF_COMMA),
    SF_METRICS_METERS(SF_COMMA),
#undef SF_METRICS_MAKE
    SFMetricsNumMetrics,
};

typedef struct {
    double sum;
    double sumsq;
    NSInteger count;
} SFMetricsMeter;

NSString *SFMetricsMetricName(SFMetricsKey key);

@interface SFMetrics : NSObject

+ (instancetype)sharedMetrics;

- (void)count:(SFMetricsKey)counterKey;

- (void)count:(SFMetricsKey)counterKey value:(NSInteger)value;

- (void)measure:(SFMetricsKey)meterKey value:(double)value;

- (void)enumerateCountersUsingBlock:(void (^)(SFMetricsKey key, NSInteger count))block;

- (void)enumerateMetersUsingBlock:(void (^)(SFMetricsKey key, const SFMetricsMeter *meter))block;

- (void)reset;

@end
