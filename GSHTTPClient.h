//
//  SLHTTPClient.h
//  LSNets
//
//  Created by Samuel on 12/9/14.
//
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFURLSessionManager.h>
#import "GSHTTPReqeust.h"

FOUNDATION_EXTERN NSString * const KZhierErrorDomain;
FOUNDATION_EXTERN NSString * const KClientId;
FOUNDATION_EXTERN NSString * const FMTKEY;
FOUNDATION_EXTERN NSString * const FMT_VALUE;

typedef void (^GSCommonSuccessBlock)(id response);

@interface GSHTTPClient : NSObject

#pragma mark - init

+ (void)configWithBaseUrl:(NSString *)baseUrl;

+ (void)configWithInBootPage:(BOOL)inBootPage;

+ (void)configWithDisableGrey:(BOOL)disableGrey;

+ (BOOL)disableGrey;

#pragma mark - 请求

//params 自动绑定一些公共参数
//bindClass 传nil自动转换为SBasicResponseModel 传NSDictionary不进行转换 传具体的Model自动转换为model类型

+ (void)sendRequest:(GSHTTPReqeust *)request
  completionHandler:(GSServerCompletionHandler)completionHandler;

+ (void)requestWithMethod:(GSRequestMethodType)method
                     path:(NSString *)path
                paraments:(id)params
                bindClass:(Class)bindClass
                cacheTime:(NSInteger)cacheTime
        completionHandler:(GSServerCompletionHandler)completionHandler;

//params 不绑定一些公共参数, 当链接为外链时才使用
+ (void)commonRequestWithMethod:(GSRequestMethodType)method
                           path:(NSString *)path
                         params:(id)params
                   successBlock:(void(^)(id rDictionary))successBlock
                      failBlock:(void(^)(NSError *error))failBlock;

#pragma mark - 上传文件

+ (void)postFileWithPath:(NSString *)path
                  params:(id)params
               imageData:(NSData *)imageData
                fileName:(NSString *)fileName
               bindClass:(Class)bindClass
       completionHandler:(GSServerCompletionHandler)completionHandler;

#pragma mark - 下载文件, 支持断点下载

+ (void)downloadWithUrl:(NSString *)url
             parameters:(id)parameters
         successHandler:(void(^)(NSURL *filePath))successHandler
         failureHandler:(void(^)(NSError *error))failureHandler;

+ (void)downloadWithLocalPath:(NSString *)localPath
                    remoteUrl:(NSString *)remoteUrl
                   parameters:(id)parameters
               successHandler:(void(^)(NSURL *filePath))successHandler
               failureHandler:(void(^)(NSError *error))failureHandler;

#pragma mark - Convenience Request

+ (void)easyGetPath:(NSString *)path
          paraments:(id)params
          bindClass:(Class)bindClass
  completionHandler:(GSServerCompletionHandler)completionHandler;

+ (void)easyPostPath:(NSString *)path
           paraments:(id)params
           bindClass:(Class)bindClass
   completionHandler:(GSServerCompletionHandler)completionHandler;

+ (void)easyPutPath:(NSString *)path
          paraments:(id)params
          bindClass:(Class)bindClass
  completionHandler:(GSServerCompletionHandler)completionHandler;

+ (void)easyHeadPath:(NSString *)path
           paraments:(id)params
           bindClass:(Class)bindClass
   completionHandler:(GSServerCompletionHandler)completionHandler;

+ (void)easyDeletePath:(NSString *)path
             paraments:(id)params
             bindClass:(Class)bindClass
     completionHandler:(GSServerCompletionHandler)completionHandler;



#pragma mark - Help

+ (NSError *)errorWithCode:(NSInteger)code msg:(NSString *)msg;

+ (NSError *)serverErrorWithMsg:(NSString *)msg;

+ (NSString *)cacheKeyWithPath:(NSString *)path;

+ (NSString *)md5:(NSString *)string;

+ (void)getCacheResponseWithRequest:(GSHTTPReqeust *)request
                              error:(NSError *)error
                  completionHandler:(GSServerCompletionHandler)completionHandler;

@end



