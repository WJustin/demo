//
//  GSHTTPReqeust.m
//  GoShare2
//
//  Created by Justin.wang on 2019/11/27.
//  Copyright © 2019 只二. All rights reserved.
//

#import "GSHTTPReqeust.h"

@implementation GSHTTPReqeust

- (instancetype)init {
    if (self = [super init]) {
        self.requestTime = [@([[NSDate date] timeIntervalSince1970] * 1000) integerValue];
    }
    return self;
}

- (NSString *)realJsonName {
    NSString *jsonName;
#if DEBUG
    jsonName = self.debugJsonName;
#else
    jsonName = self.jsonName;
#endif
    return jsonName;
}

@end

@implementation GSHTTPReqeustPagckage


@end
