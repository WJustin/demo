//
//  GSHTTPSessionManager.h
//  GoShare2
//
//  Created by Justin.wang on 2019/11/27.
//  Copyright © 2019 只二. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>

@interface GSHTTPSessionManager : AFHTTPSessionManager

+ (instancetype)sharedSessionWithUrl:(NSString *)url;

+ (void)gs_configWithIsOpenProxy:(BOOL)isOpenProxy;

+ (BOOL)gs_openProxy;

@end
