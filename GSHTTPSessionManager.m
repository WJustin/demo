//
//  GSHTTPSessionManager.m
//  GoShare2
//
//  Created by Justin.wang on 2019/11/27.
//  Copyright © 2019 只二. All rights reserved.
//

#import "GSHTTPSessionManager.h"
#import "GSErrorReport.h"
#import "GSSerSingleton.h"
#import <Base64/MF_Base64Additions.h>

static NSMutableDictionary *TaskMutableDics;
static dispatch_queue_t SearialQueue;

static NSString * const kSessionProxyKey = @"gs_SessionProxyKey";

static BOOL GS_IsOpenProxy = NO; //是否禁止抓包

@implementation GSHTTPSessionManager

+ (void)gs_configWithIsOpenProxy:(BOOL)isOpenProxy {
    [[NSUserDefaults standardUserDefaults] setValue:isOpenProxy ? @(1) : @(0) forKey:kSessionProxyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    GS_IsOpenProxy = isOpenProxy;
}

+ (BOOL)gs_openProxy {
    return GS_IsOpenProxy;
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        TaskMutableDics = [[NSMutableDictionary alloc] init];
        SearialQueue = dispatch_queue_create("com.zhier.apm", DISPATCH_QUEUE_SERIAL);
        NSNumber *number = [[NSUserDefaults standardUserDefaults] valueForKey:kSessionProxyKey];
        if (!number) {
#ifdef TEST
            GS_IsOpenProxy = YES; //测试版默认开启
#else
            GS_IsOpenProxy = NO; //正式版默认关闭
#endif
        } else {
            GS_IsOpenProxy = [number integerValue] > 0;
        }
    });
}

+ (instancetype)sharedSessionWithUrl:(NSString *)url {
    static GSHTTPSessionManager *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        //禁止抓包工具抓包
        if ([self gs_openProxy]) {
            config.connectionProxyDictionary = nil;
        } else {
            config.connectionProxyDictionary = @{};
        }
        _sharedClient = [[GSHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:url] sessionConfiguration:config];
        _sharedClient.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:
                                                                   @"application/json",
                                                                   @"text/html",
                                                                   @"text/json",
                                                                   @"text/javascript",
                                                                   @"text/plain",nil];
        _sharedClient.operationQueue.maxConcurrentOperationCount = 4;
        [_sharedClient setTaskDidCompleteBlock:^(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSError * _Nullable error) {
            dispatch_async(SearialQueue, ^{
                NSURLSessionTaskMetrics *metrics;
                if (task.taskIdentifier > 0) {
                    metrics = TaskMutableDics[@(task.taskIdentifier).stringValue];
                }
                if (!error) {
                    if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
                        NSInteger statusCode = ((NSHTTPURLResponse *)task.response).statusCode;
                        NSInteger code = 200;
                        NSString *msg;
                        if (statusCode != 200) {
                            code = statusCode;
                            msg = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
                        } else {//成功的响应通过AFN通知获取
                            
                        }
                        [GSErrorReport reportWithTask:task
                                              metrics:metrics
                                            errorCode:code
                                             errorMsg:msg
                                              content:nil];
                    }
                } else if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
                    
                } else {
                    [GSErrorReport reportWithTask:task
                                          metrics:metrics
                                        errorCode:error.code
                                         errorMsg:error.localizedDescription
                                          content:nil];
                }
                
            });
        }];
        [[NSNotificationCenter defaultCenter] addObserver:_sharedClient
                                                 selector:@selector(handleResponse:)
                                                     name:AFNetworkingTaskDidCompleteNotification
                                                   object:nil];
    });
    return _sharedClient;
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
    dispatch_async(SearialQueue, ^{
        if (task.taskIdentifier > 0) {
            [TaskMutableDics addEntriesFromDictionary:@{@(task.taskIdentifier).stringValue : metrics}];
        }
    });
}

- (void)handleResponse:(NSNotification *)notification {
    dispatch_async(SearialQueue, ^{
        if ([notification.object isKindOfClass:[NSURLSessionTask class]]) {
            NSURLSessionTask *task = notification.object;
            NSDictionary *userInfo = notification.userInfo;
            NSError *error = userInfo[AFNetworkingTaskDidCompleteErrorKey];
            NSURLSessionTaskMetrics *metrics;
            if (task.taskIdentifier > 0) {
                metrics = TaskMutableDics[@(task.taskIdentifier).stringValue];
            }
            NSDictionary *repsonseDic = userInfo[AFNetworkingTaskDidCompleteSerializedResponseKey];
            if (error && [error isKindOfClass:[NSError class]]) {
                NSData *data = userInfo[AFNetworkingTaskDidCompleteResponseDataKey];
                NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSInteger code = error.code;
                if (code == 3840) {//返回数据不是json, code重置为500
                    code = 500;
                }
                [GSErrorReport reportWithTask:task
                                      metrics:metrics
                                    errorCode:code
                                     errorMsg:error.localizedDescription
                                      content:string];
            } else if (repsonseDic &&
                       [repsonseDic isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dic = userInfo[AFNetworkingTaskDidCompleteSerializedResponseKey];
                SBasicResponseModel *response = [[SBasicResponseModel alloc] initWithDictionary:dic];
                NSInteger code = [response.code integerValue];
                [GSErrorReport reportWithTask:task
                                      metrics:metrics
                                    errorCode:code
                                     errorMsg:response.msg
                                      content:nil];
            } else if (!repsonseDic) { //内容为空
                [GSErrorReport reportWithTask:task
                                      metrics:metrics
                                    errorCode:500
                                     errorMsg:@""
                                      content:nil];
            } else if (repsonseDic && [repsonseDic isKindOfClass:[NSString class]]) {
                NSString *responseStr = (NSString *)repsonseDic;
                [GSErrorReport reportWithTask:task
                                      metrics:metrics
                                    errorCode:500
                                     errorMsg:@""
                                      content:responseStr];
            }
            [TaskMutableDics removeObjectForKey:@(task.taskIdentifier).stringValue];
        }
    });
}

@end
