//
//  Sift.m
//  Sift
//
//  Created by Che-Liang Chiou on 8/25/15.
//  Copyright © 2015 Sift Science. All rights reserved.
//

#import "Sift.h"

NSString* IDENTIFIER = @"com.sift.BeaconBackgroundSession";

NSString* TRACKER = @"https://b.siftscience.com";

@implementation Sift

+ (Sift *)sharedInstance {
    static Sift *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Sift alloc] initWithIdentifier:IDENTIFIER];
    });
    return sharedInstance;
}

- (id)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        self.session = [NSURLSession sessionWithConfiguration:defaultConfigurationWithIdentifier(identifier) delegate:self delegateQueue:nil];
        self.tracker = TRACKER;
        self.referer = @"";
        self.completionHandler = nil;
    }
    return self;
}

NSURLSessionConfiguration *defaultConfigurationWithIdentifier(NSString *identifier) {
    return [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
}

- (void)track:(NSString *)url title:(NSString *)title {
    NSString *trackerUrl = [Sift track:url title:title tracker:self.tracker referer:self.referer];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:trackerUrl]];
    [[self.session uploadTaskWithRequest:request fromFile:[NSURL URLWithString:@"file:///dev/null"]] resume];
    self.referer = url;
}

+ (NSString *)track:(NSString *)url title:(NSString *)title tracker:(NSString *)tracker referer:(NSString *)referer {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    // TODO: These are the attributes we collect in sift.js (we probably won't collect all of them here).
    
    //attributes[@"bk"] = beaconKey;

    //attributes[@"tm"] = time;
    //attributes[@"r"] = random;
    //attributes[@"v"] = version;
    //attributes[@"cs"] = characterSet;
    //attributes[@"h"] = hostName;
    //attributes[@"l"] = language;

    //attributes[@"P"] = partnerUserId;
    //attributes[@"S"] = sessionId;
    //attributes[@"ui"] = userId;
    //attributes[@"uu"] = userUuid;
    attributes[@"t"] = title;
    attributes[@"u"] = url;

    attributes[@"rf"] = referer;
    //attributes[@"ua"] = userAgent;

    //attributes[@"nm"] = numMimeTypes;
    //attributes[@"mh"] = mimeTypeHash;
    //attributes[@"nf"] = numFonts;
    //attributes[@"fh"] = fontsHash;
    //attributes[@"np"] = numPlugins;
    //attributes[@"ph"] = plugingHash;

    //attributes[@"sh"] = screenHeight;
    //attributes[@"sw"] = screenWidth;
    //attributes[@"cd"] = colorDepth;
    //attributes[@"p"] = platform;

    //attributes[@"to"] = timezoneOffset;
    //attributes[@"d"] = dstOffset;

    //attributes[@"si"] = flash_SocketIP;
    //attributes[@"fu"] = flash_uuid;

    // Sort outputs so that unit testing is easier.
    NSArray *sortedKeys = [attributes.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *parts = [NSMutableArray arrayWithCapacity:[sortedKeys count]];
    NSCharacterSet *queryCharacterSet = [NSCharacterSet URLQueryAllowedCharacterSet];
    for (id key in sortedKeys) {
        NSString *escaped = [attributes[key] stringByAddingPercentEncodingWithAllowedCharacters:queryCharacterSet];
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, escaped]];
    }
    return [NSString stringWithFormat:@"%@/i.gif?%@&z=z", tracker, [parts componentsJoinedByString:@"&"]];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    if (self.completionHandler) {
        self.completionHandler(session, task, error);
    }
}

@end