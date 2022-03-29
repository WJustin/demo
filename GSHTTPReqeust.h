//
//  GSHTTPReqeust.h
//  GoShare2
//
//  Created by Justin.wang on 2019/11/27.
//  Copyright © 2019 只二. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GSHTTPSessionManager.h"

typedef void (^GSServerCompletionHandler)(id responseObject, NSError *error);

typedef NS_ENUM(NSInteger, GSRequestMethodType) {
    GSRequestMethodTypeGet,
    GSRequestMethodTypePost,
    GSRequestMethodTypeHead,
    GSRequestMethodTypePut,
    GSRequestMethodTypePatch,
    GSRequestMethodTypeDelete,
};

typedef NS_ENUM(NSInteger, GSRequestClassType) {
    GSRequestClassTypeNone, //不校验
    GSRequestClassTypeArray, //array
    GSRequestClassTypeObject, // object类型
};

@interface GSHTTPReqeust : NSObject

//请求方式
@property (nonatomic, assign) GSRequestMethodType methodType;

//请求路径
@property (nonatomic, copy  ) NSString *path;

//请求参数
@property (nonatomic, strong) id params;

//模型类型
@property (nonatomic, strong) Class bindClass;

@property (nonatomic, assign) GSRequestClassType classType;


@property (nonatomic, weak  ) NSURLSessionDataTask *sessionTask;

/*
 本地json文件名, 用于网络失败时，返回该份文件的内容， 可为空
 jsonName: 线上环境
 debugJsonName: 测试环境
 realJsonName: 返回当前环境使用的本地json文件名
 */
@property (nonatomic, copy  ) NSString *jsonName;
@property (nonatomic, copy  ) NSString *debugJsonName;
@property (nonatomic, copy, readonly) NSString *realJsonName;

//设置响应的缓存Key，如果没有设置，默认设置path的md5值作为key值
@property (nonatomic, copy  ) NSString *cacheKey;

//设置响应的缓存时间，如果没有设置， 默认从response header cache control解析
@property (nonatomic, assign) NSInteger cacheTime;

//默认为Yes, YES: AFJSONRequestSerializer, NO: AFHTTPRequestSerializer
@property (nonatomic, assign) BOOL isJson;

@property (nonatomic, assign) BOOL isRefresh;

/*
  以下两个属性用于处理401所用，业务方不要使用
 */
@property (nonatomic, assign) NSInteger requestTime;
@property (nonatomic, assign) BOOL isUpateRefreshToken;

@end

@interface GSHTTPReqeustPagckage : NSObject

@property (nonatomic, strong) GSHTTPReqeust *request;
@property (nonatomic, copy  ) GSServerCompletionHandler completeHandler;

@end
