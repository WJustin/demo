//
//  SLHTTPClient.m
//  LSNets
//
//  Created by Samuel on 12/9/14.
//
//

#import "GSHTTPClient.h"
#import "GSSerSingleton.h"
#import "SBasicResponseModel.h"
#import "SBasicRequestModel.h"
#import "GSErrorReport.h"
#import "GSCacheManager.h"
#import <CommonCrypto/CommonDigest.h>
#import "GSHTTPSessionManager.h"
#import "SUrlDeploy.h"

NSString * const KZhierErrorDomain = @"com.goshare2.error";

static NSString * const KMaxAageKey = @"max-age";
static NSInteger const GSHTTPClientloadingServerErrorCode = 10002;
static NSString * BaseUrl = nil;
static BOOL InBootPage = NO;

NSString * const KClientId = @"ZHIER_APP";
NSString * const KClientSecret = @"JKASDFLKKLJKFDOOUI";

NSString * const FMTKEY = @"fmt";
NSString * const FMT_VALUE = @"1";

static NSString * const kGreyKey = @"kGreyKey";

static NSInteger RefreshTokenRetrySuccessTimes = 0;
//static NSInteger UpdateTokenTime = 0;
static NSMutableArray <GSHTTPReqeustPagckage *> *GlobalMuatableArray;

typedef void(^GetCacheResponseBlock)(NSDictionary *dic);

@implementation GSHTTPClient

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        GlobalMuatableArray = [[NSMutableArray alloc] init];
    });
}

+ (void)configWithBaseUrl:(NSString *)baseUrl {
    BaseUrl = baseUrl;
}

+ (void)configWithInBootPage:(BOOL)inBootPage {
    InBootPage = inBootPage;
}

+ (void)configWithDisableGrey:(BOOL)disableGrey {
    [[NSUserDefaults standardUserDefaults] setBool:disableGrey forKey:kGreyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)disableGrey {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kGreyKey];
}

#pragma mark - Request

+ (void)sendRequest:(GSHTTPReqeust *)request
  completionHandler:(GSServerCompletionHandler)completionHandler {
    if ([request.path containsString:[SUrlDeploy sharedSUrlDeploy].authUrl]) {
        if (request.params && [request.params isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *mutableDic = [[NSMutableDictionary alloc] init];
            [mutableDic addEntriesFromDictionary:request.params];
            [mutableDic addEntriesFromDictionary:@{FMTKEY : FMT_VALUE}];
            request.params = mutableDic;
        }
        if (!request.params) {
            request.params = @{FMTKEY : FMT_VALUE};
        }
    }
    if (!request.cacheKey.isNotBland) {
         request.cacheKey = [self cacheKeyWithPath:request.path];
    }
    GSServerCompletionHandler completeBlock = ^(id response, NSError *error) {
//        if ((error.code == 401) &&
//            [GSSerSingleton shareSingleton].isLogin) {
//            if (request.isUpateRefreshToken) {
//                if (completionHandler) {
//                    completionHandler(nil, error);
//                }
//                return;
//            }
//            if (request.requestTime >= UpdateTokenTime) {
//                if (GlobalMuatableArray.count == 0) {
//                    [GSAuthService updateTokenWithCompleteHandler:^(id responseObject, NSError *error) {
//                        if (!error) {
//                            if (RefreshTokenRetrySuccessTimes > 2) { //防止其他接口固定返回401导致一直refresh_token,使得陷入死循环
//                                [self postDueNotification];
//                                return;
//                            }
//                            if (RefreshTokenRetrySuccessTimes == 0) {
//                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                                    RefreshTokenRetrySuccessTimes = 0;
//                                });
//                            }
//                            RefreshTokenRetrySuccessTimes++;
//                            NSInteger currentTime = [@([[NSDate date] timeIntervalSince1970] * 1000) integerValue];
//                            request.requestTime = currentTime;
//                            UpdateTokenTime = currentTime;
//                            [GlobalMuatableArray enumerateObjectsUsingBlock:^(GSHTTPReqeustPagckage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//                                [self sendRequest:obj.request completionHandler:obj.completeHandler];
//                            }];
//                            GlobalMuatableArray = [[NSMutableArray alloc] init];
//                        } else {
//                            if (error.code == 400 || error.code == 401) {
//                                [self postDueNotification];
//                            } else {
//                                [GlobalMuatableArray enumerateObjectsUsingBlock:^(GSHTTPReqeustPagckage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//                                    if (obj.completeHandler) {
//                                        obj.completeHandler(nil, error);
//                                    }
//                                }];
//                                GlobalMuatableArray = [[NSMutableArray alloc] init];
//                            }
//                        }
//                    }];
//                }
//                GSHTTPReqeustPagckage *package = [[GSHTTPReqeustPagckage alloc] init];
//                package.request = request;
//                package.completeHandler = completionHandler;
//                [GlobalMuatableArray addObject:package];
//            } else {
//                request.requestTime = [@([[NSDate date] timeIntervalSince1970] * 1000) integerValue];
//                [self sendRequest:request completionHandler:completionHandler];
//            }
//        } else {
            if (completionHandler) {
                completionHandler(response, error);
                
            }
//        }
    };
    [[GSCacheManager shareManager] objectForKey:request.isRefresh ? nil : request.cacheKey
                             removedAfterExpire:YES
                                          block:^(GSCacheModel * _Nullable cacheModel) {
                                              if (cacheModel && cacheModel.data){
                                                  [self convertDic:cacheModel.data
                                                             error:nil
                                                         cacheTime:0
                                                           request:request
                                                 completionHandler:completeBlock];
                                                  return;
                                              }
                                              [self handlePath:request.path
                                                        params:request.params
                                               completeHandler:^(NSString *nPath, NSDictionary *nParams) {
                                                   request.path = nPath;
                                                   request.params = nParams;
                                                   [self sendCommonRequest:request successBlock:^(id rDictionary) {
                                                       if (request.methodType == GSRequestMethodTypeGet &&
                                                           request.cacheTime <= 0 &&
                                                           [rDictionary isKindOfClass:[NSDictionary class]]) {
                                                           NSString *maxAgeString = rDictionary[KMaxAageKey];
                                                           request.cacheTime = [(maxAgeString ?: @"") integerValue];
                                                       }
                                                       [self convertDic:rDictionary
                                                                  error:nil
                                                              cacheTime:request.cacheTime
                                                                request:request
                                                      completionHandler:completeBlock];
                                                   } failBlock:^(NSError *error) {
                                                       [self convertDic:nil
                                                                  error:error
                                                              cacheTime:0
                                                                request:request
                                                      completionHandler:completeBlock];
                                                   }];
                                               }];
                                          }];
}

+ (void)requestWithMethod:(GSRequestMethodType)method
                     path:(NSString *)path
                paraments:(id)params
                bindClass:(Class)bindClass
                cacheTime:(NSInteger)cacheTime
        completionHandler:(GSServerCompletionHandler)completionHandler {
    GSHTTPReqeust *request = [[GSHTTPReqeust alloc] init];
    request.methodType = method;
    request.path = path;
    request.bindClass = bindClass;
    request.cacheTime = cacheTime;
    request.params = params;
    [self sendRequest:request completionHandler:completionHandler];
}

+ (void)postFileWithPath:(NSString *)path
                  params:(id)params
               imageData:(NSData *)imageData
                fileName:(NSString *)fileName
               bindClass:(Class)bindClass
       completionHandler:(GSServerCompletionHandler)completionHandler {
    [self handlePath:path params:params completeHandler:^(NSString *nPath, NSDictionary *nParams) {
        NSMutableDictionary *mutableDic = [nParams ?: @{} mutableCopy];
        [self commonPostFileWithPath:nPath
                              params:mutableDic
                           imageData:imageData
                            fileName:fileName
                   completionHandler:^(id responseObject, NSError *error) {
            if (!error) {
                [self updateWithResponse:responseObject];
                [self convertResponse:responseObject
                          toBindClass:bindClass
                            classType:GSRequestClassTypeNone
                            cacheTime:0
                             cacheKey:nil
                    completionHandler:completionHandler];
            } else {
                if (completionHandler) {
                    completionHandler(nil, error);
                }
            }
        }];
    }];
}

+ (void)sendCommonRequest:(GSHTTPReqeust *)request
             successBlock:(void(^)(id rDictionary))successBlock
                failBlock:(void(^)(NSError *error))failBlock {
    GSHTTPSessionManager *session = [self sessionWithRequest:request];
    ___WEAKSELF
    void (^successHandler)(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) = ^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        if (httpResponse.statusCode == 200) {
            dispatch_async(dispatch_get_main_queue(), ^{
                request.sessionTask = nil;
                NSDictionary *dic = responseObject;
                NSDictionary *allHeaderFields = httpResponse.allHeaderFields;
                if ((request.methodType == GSRequestMethodTypeGet ||
                     request.methodType == GSRequestMethodTypePost) &&
                    allHeaderFields.count > 0 &&
                    allHeaderFields[@"Cache-Control"] &&
                    [responseObject isKindOfClass:[NSDictionary class]]) {
                    NSString *cacheHeaderString = allHeaderFields[@"Cache-Control"];
                    if ([cacheHeaderString containsString:KMaxAageKey]) {
                        NSMutableDictionary *mutableDic = [[NSMutableDictionary alloc] initWithDictionary:responseObject];
                        NSArray<NSString *> *equalArray = [cacheHeaderString componentsSeparatedByString:@","];
                        __block NSString *maxAageString = nil;
                        [equalArray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            if ([obj containsString:KMaxAageKey]) {
                                maxAageString = obj;
                            }
                        }];
                        if (maxAageString.isNotBland) {
                            NSArray <NSString *> *ageArray = [maxAageString componentsSeparatedByString:@"="];
                            NSInteger age = [[ageArray lastObject] integerValue];
                            if (age > 0) {
                                [mutableDic addEntriesFromDictionary:@{ KMaxAageKey : @(age).stringValue }];
                            }
                            dic = mutableDic;
                        }
                    }
                }
                [weakSelf updateWithResponse:dic];
                if (successBlock) {
                    successBlock(dic);
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                request.sessionTask = nil;
                if (failBlock) {
                    failBlock([self serverErrorWithMsg:@"响应数据格式有误"]);
                }
            });
        }
    };
    void (^failHandler)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) = ^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            request.sessionTask = nil;
            if (failBlock) {
                if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
                    NSHTTPURLResponse *rep = (NSHTTPURLResponse *)task.response;
                    if (rep.statusCode != 200) {
                        NSString *localizedDesc = error.localizedDescription;
                        NSData *data = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
                        if (data) {
                            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                            if (string) {
                                SBasicResponseModel *response = [SBasicResponseModel yy_modelWithJSON:string];
                                if (response.msg.isNotBland) {
                                    localizedDesc = response.msg;
                                }
                            }
                        }
                        NSError *er = [NSError errorWithDomain:error.domain
                                                          code:rep.statusCode
                                                      userInfo:@{@"NSLocalizedDescription" : localizedDesc ?: @""}];
                        failBlock(er);
                        return;
                    }
                }
                NSString *customMsg = nil;
                if (error.code == -1009 || error.code == -1020) {//-1009: 似乎已断开与互联网的连接  -1020:目前不允许数据连接
                    customMsg = @"当前无网络，请等网络连接后重试";
                }
//                if (error.code == -1001) {//请求超时
//                    customMsg = @"当前无网络，请等网络连接后重试";
//                }
                if (customMsg) {
                    failBlock([GSServer errorWithCode:error.code msg:customMsg]);
                    return;
                }
                failBlock(error);
            }
        });
    };
    if (request.methodType == GSRequestMethodTypeGet) {
        request.sessionTask =
        [session GET:request.path parameters:request.params progress:nil success:successHandler failure:failHandler];
    } else if (request.methodType == GSRequestMethodTypePost) {
        request.sessionTask =
        [session POST:request.path parameters:request.params progress:nil success:successHandler failure:failHandler];
    } else if (request.methodType == GSRequestMethodTypeHead) {
        request.sessionTask =
        [session HEAD:request.path parameters:request.params success:^(NSURLSessionDataTask * _Nonnull task) {
            if (successHandler) {
                successHandler(task, nil);
            }
        } failure:failHandler];
    } else if (request.methodType == GSRequestMethodTypePut) {
        request.sessionTask =
        [session PUT:request.path parameters:request.params success:successHandler failure:failHandler];
    } else if (request.methodType == GSRequestMethodTypePatch) {
        request.sessionTask =
        [session PATCH:request.path parameters:request.params success:successHandler failure:failHandler];
    } else if (request.methodType == GSRequestMethodTypeDelete) {
        request.sessionTask =
        [session DELETE:request.path parameters:request.params success:successHandler failure:failHandler];
    }
}

+ (void)commonRequestWithMethod:(GSRequestMethodType)method
                           path:(NSString *)path
                         params:(id)params
                   successBlock:(void(^)(id rDictionary))successBlock
                      failBlock:(void(^)(NSError *error))failBlock {
    GSHTTPReqeust *request = [[GSHTTPReqeust alloc] init];
    request.methodType = method;
    request.path = path;
    request.params = params;
    [self sendCommonRequest:request successBlock:successBlock failBlock:failBlock];
}

+ (void)commonPostFileWithPath:(NSString *)path
                        params:(id)params
                     imageData:(NSData *)imageData
                      fileName:(NSString *)fileName
             completionHandler:(GSServerCompletionHandler)completionHandler {
    GSHTTPReqeust *request = [[GSHTTPReqeust alloc] init];
    request.path = path;
    request.params = params;
    GSHTTPSessionManager *session = [self sessionWithRequest:request];
    [session POST:path parameters:params ?: @{} constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:imageData
                                    name:@"pic"
                                fileName:fileName
                                mimeType:@"image/jpeg"];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        if (httpResponse.statusCode == 200 && responseObject) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler) {
                    completionHandler(responseObject, nil);
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler) {
                    completionHandler(nil, [self serverErrorWithMsg:@"响应数据格式有误"]);
                }
            });
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completionHandler) {
            completionHandler(nil, error);
        }
    }];
}

+ (void)downloadWithUrl:(NSString *)url
             parameters:(id)parameters
         successHandler:(void(^)(NSURL * _Nullable filePath))successHandler
         failureHandler:(void(^)(NSError *error))failureHandler {
    NSString *localPath = [self cacheLocalPathWithUrl:url];
    [self downloadWithLocalPath:localPath
                      remoteUrl:url
                     parameters:parameters
                 successHandler:successHandler
                 failureHandler:failureHandler];
}

+ (void)downloadWithLocalPath:(NSString *)localPath
                    remoteUrl:(NSString *)remoteUrl
                   parameters:(id)parameters
               successHandler:(void(^)(NSURL * _Nullable filePath))successHandler
               failureHandler:(void(^)(NSError *error))failureHandler  {
    if (!remoteUrl.isNotBland) {
        if (failureHandler) {
            failureHandler([self serverErrorWithMsg:@"url不能为空"]);
        }
        return;
    }
    // add parameters to URL;
    GSHTTPReqeust *request = [[GSHTTPReqeust alloc] init];
    GSHTTPSessionManager *session = [self sessionWithRequest:request];
    NSError *err;
    NSMutableURLRequest *urlRequest = [session.requestSerializer requestWithMethod:@"GET"
                                                                         URLString:remoteUrl
                                                                        parameters:parameters
                                                                             error:&err];
    if (err) {
        if (failureHandler) {
            failureHandler(err);
        }
        return;
    }
    
    NSString *downloadTargetPath;
    BOOL isDirectory;
    if(![[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory]) {
        isDirectory = NO;
    }
    // If targetPath is a directory, use the file name we got from the urlRequest.
    // Make sure downloadTargetPath is always a file, not directory.
    if (isDirectory) {
        NSString *fileName = [urlRequest.URL lastPathComponent];
        downloadTargetPath = [NSString pathWithComponents:@[localPath, fileName]];
    } else {
        downloadTargetPath = localPath;
    }
    
    // AFN use `moveItemAtURL` to move downloaded file to target path,
    // this method aborts the move attempt if a file already exist at the path.
    // So we remove the exist file before we start the download task.
    // https://github.com/AFNetworking/AFNetworking/issues/3775
    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadTargetPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:downloadTargetPath error:nil];
    }
    
    BOOL resumeDataFileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self incompleteDownloadTempPathForDownloadPath:localPath].path];
    NSData *data = [NSData dataWithContentsOfURL:[self incompleteDownloadTempPathForDownloadPath:localPath]];
    BOOL resumeDataIsValid = [self validateResumeData:data];
    
    BOOL canBeResumed = resumeDataFileExists && resumeDataIsValid;
    BOOL resumeSucceeded = NO;
    __block NSURLSessionDownloadTask *downloadTask = nil;
    // Try to resume with resumeData.
    // Even though we try to validate the resumeData, this may still fail and raise excecption.
    void (^failureBlock)(NSError *error) = ^(NSError *error){
        // Save incomplete download data.
        if (error && error.userInfo) {
            NSData *incompleteDownloadData = error.userInfo[NSURLSessionDownloadTaskResumeData];
            if (incompleteDownloadData) {
                [incompleteDownloadData writeToURL:[self incompleteDownloadTempPathForDownloadPath:localPath] atomically:YES];
            }
        }
        if (failureHandler) {
            failureHandler(error);
        }
    };
    void (^completeBlock)(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) = ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 200 && !error && filePath.absoluteString.isNotBland) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (successHandler) {
                    successHandler(filePath);
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failureBlock) {
                    failureBlock(error);
                }
            });
        }
    };
    if (canBeResumed) {
        @try {
            downloadTask = [session downloadTaskWithResumeData:data progress:nil destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
            } completionHandler:
                            ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                                completeBlock(response, filePath, error);
                            }];
            resumeSucceeded = YES;
        } @catch (NSException *exception) {
            resumeSucceeded = NO;
        }
    }
    if (!resumeSucceeded) {
        downloadTask = [session downloadTaskWithRequest:urlRequest progress:nil destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            return [NSURL fileURLWithPath:downloadTargetPath isDirectory:NO];
        } completionHandler:
                        ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                            completeBlock(response, filePath, error);
                        }];
    }
    [downloadTask resume];
}


#pragma mark - Convenience Request

+ (void)easyGetPath:(NSString *)path
          paraments:(id)params
          bindClass:(Class)bindClass
  completionHandler:(GSServerCompletionHandler)completionHandler {
    [self requestWithMethod:GSRequestMethodTypeGet
                       path:path
                  paraments:params
                  bindClass:bindClass
                  cacheTime:0
          completionHandler:completionHandler];
}

+ (void)easyPostPath:(NSString *)path
           paraments:(id)params
           bindClass:(Class)bindClass
   completionHandler:(GSServerCompletionHandler)completionHandler {
    [self requestWithMethod:GSRequestMethodTypePost
                       path:path
                  paraments:params
                  bindClass:bindClass
                  cacheTime:0
          completionHandler:completionHandler];
}

+ (void)easyPutPath:(NSString *)path
          paraments:(id)params
          bindClass:(Class)bindClass
  completionHandler:(GSServerCompletionHandler)completionHandler {
    [self requestWithMethod:GSRequestMethodTypePut
                       path:path
                  paraments:params
                  bindClass:bindClass
                  cacheTime:0
          completionHandler:completionHandler];
}

+ (void)easyHeadPath:(NSString *)path
          paraments:(id)params
          bindClass:(Class)bindClass
  completionHandler:(GSServerCompletionHandler)completionHandler {
    [self requestWithMethod:GSRequestMethodTypeHead
                       path:path
                  paraments:params
                  bindClass:bindClass
                  cacheTime:0
          completionHandler:completionHandler];
}

+ (void)easyDeletePath:(NSString *)path
             paraments:(id)params
             bindClass:(Class)bindClass
     completionHandler:(GSServerCompletionHandler)completionHandler {
    [self requestWithMethod:GSRequestMethodTypeDelete
                       path:path
                  paraments:params
                  bindClass:bindClass
                  cacheTime:0
          completionHandler:completionHandler];
}

#pragma mark - Help

+ (NSError *)errorWithCode:(NSInteger)code msg:(NSString *)msg {
    NSError *error = [NSError errorWithDomain:KZhierErrorDomain
                                         code:code
                                     userInfo:@{@"NSLocalizedDescription" : msg ?: @""}];
    return error;
}


+ (NSError *)serverErrorWithMsg:(NSString *)msg {
    return [self errorWithCode:GSHTTPClientloadingServerErrorCode msg:msg];
}

+ (void)convertDic:(id)dic
             error:(NSError *)error
         cacheTime:(NSInteger)cacheTime
           request:(GSHTTPReqeust *)request
   completionHandler:(GSServerCompletionHandler)completionHandler {
    if (!error && dic && cacheTime > 0) {
        SBasicResponseModel *baseRequest = [[SBasicResponseModel alloc] initWithDictionary:dic];
        if (baseRequest.state == NO) {
            error = [GSServer errorWithCode:[baseRequest.code integerValue] msg:baseRequest.msg];
        }
    }
    if (error) {
        NSString *str;
//#if DEBUG
//                str = [NSString stringWithFormat:@"%@:%@",  @(error.code), error.localizedDescription];
//#else
        str = error.localizedDescription;
//#endif
        NSError *err = [GSServer errorWithCode:error.code msg: str];
        [self getCacheResponseWithRequest:request
                                    error:err
                        completionHandler:completionHandler];
    } else {
        [self convertResponse:dic
                  toBindClass:request.bindClass
                    classType:request.classType
                    cacheTime:cacheTime
                     cacheKey:request.cacheKey
            completionHandler:completionHandler];
    }
}

+ (void)getCacheResponseWithRequest:(GSHTTPReqeust *)request
                              error:(NSError *)error
                  completionHandler:(GSServerCompletionHandler)completionHandler {
    [self getCacheResponseWithJsonName:request.realJsonName
                              cacheKey:request.cacheKey
                       completeHandler:^(NSDictionary *dic) {
        if (dic) { //从缓存查找出来的不缓存
            [self convertResponse:dic
                      toBindClass:request.bindClass
                        classType:request.classType
                        cacheTime:0
                         cacheKey:request.cacheKey
                completionHandler:completionHandler];
        } else {
            if (completionHandler) {
                completionHandler(nil, error);
            }
        }
    }];
}

+ (void)getCacheResponseWithJsonName:(NSString *)jsonName
                            cacheKey:(NSString *)cacheKey
                     completeHandler:(GetCacheResponseBlock)completeHandler {
    if (cacheKey.isNotBland) {
        [[GSCacheManager shareManager] objectForKey:cacheKey
                                 removedAfterExpire:NO
                                              block:^(GSCacheModel * _Nullable model) {
            if (model.data) {
                if (completeHandler) {
                    completeHandler(model.data);
                }
                return;
            }
            [self getCacheResponseWithJsonName:jsonName completeHandler:completeHandler];
        }];
    } else {
        [self getCacheResponseWithJsonName:jsonName completeHandler:completeHandler];
    }
}

+ (void)getCacheResponseWithJsonName:(NSString *)jsonName completeHandler:(GetCacheResponseBlock)completeHandler {
    if (jsonName.isNotBland) {
        NSString *jsonPath = [[NSBundle mainBundle] pathForResource:jsonName ofType:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:jsonPath];
        if (data) {
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            if (dic) {
                if (completeHandler) {
                    completeHandler(dic);
                }
                return;
            }
        }
    }
    if (completeHandler) {
        completeHandler(nil);
    }
}

+ (void)convertResponse:(id)dic
            toBindClass:(Class)bindClass
              classType:(GSRequestClassType)classType
              cacheTime:(NSInteger)cacheTime
               cacheKey:(NSString *)cacheKey
      completionHandler:(GSServerCompletionHandler)completionHandler {
    if ([bindClass isEqual:[NSDictionary class]]) {
        if (completionHandler) {
            completionHandler(dic, nil);
        }
        return;
    }
    SBasicResponseModel *baseRequest = [[SBasicResponseModel alloc] initWithDictionary:dic];
    if (baseRequest.state == NO) {
        NSString *str;
//#if DEBUG
//        str = [NSString stringWithFormat:@"%@:%@", baseRequest.code, baseRequest.msg];
//#else
        str = baseRequest.msg;
//#endif
        NSError *error = [GSServer errorWithCode:baseRequest.code msg:str];
        if (completionHandler) {
            completionHandler(nil, error);
        }
        return;
    }
    if (cacheKey.isNotBland && cacheTime > 0) { //更新缓存
        if (cacheKey.isNotBland) {
            [[GSCacheManager shareManager] setObject:dic surviveTime:cacheTime key:cacheKey];
        }
    }

    if (bindClass) {
        id dataObject = baseRequest.data;
        id responseInstance;
        if ([dataObject isKindOfClass:[NSArray class]]) {
            if (classType == GSRequestClassTypeObject) {
                NSError *formateError = [self serverErrorWithMsg:@"返回结构类型不匹配，应为object类型,但返回了数组类型"];
                if (completionHandler) {
                    completionHandler(nil, formateError);
                }
                return;
            }
            responseInstance = [NSArray yy_modelArrayWithClass:bindClass json:dataObject];
        } else {
            if (dataObject && classType == GSRequestClassTypeArray) {
                NSError *formateError = [self serverErrorWithMsg:@"返回结构类型不匹配，应为数组类型,但返回了Object类型"];
                if (completionHandler) {
                    completionHandler(nil, formateError);
                }
                return;
            }
            responseInstance = [bindClass yy_modelWithJSON:dataObject];
        }
        if (completionHandler) {
            completionHandler(responseInstance, nil);
        }
        return;
    }
    if (completionHandler) {
        completionHandler(baseRequest, nil);
    }
}

+ (void)handlePath:(NSString *)path
            params:(id)params
   completeHandler:(void (^)(NSString *nPath, id nParams))completeHandler {
    if ([STol isNotBland:params] && [params isKindOfClass:[NSArray class]]) {
        if (completeHandler) {
            completeHandler(path, params);
        }
        return;
    }
    NSMutableDictionary *paramMutableDic = [[NSMutableDictionary alloc] initWithDictionary:params];
    if ([paramMutableDic.allKeys containsObject:@"sn"]) { //是否已经加密过了
        if (completeHandler) {
            completeHandler(path, paramMutableDic);
        }
        return;
    }
     
    if (!path) {
        NSMutableDictionary *paramMutableDic = [[NSMutableDictionary alloc] initWithDictionary:params];
        if (completeHandler) {
            completeHandler(path, [SBasicRequestModel setBaseModel:paramMutableDic]);
        }
    } else {
        __block NSMutableString *mutablePath = [path mutableCopy];
        __block  NSMutableDictionary *mutableDic = [[NSMutableDictionary alloc] init];
        if (params) {
            [params enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                NSString *template = [NSString stringWithFormat:@"{%@}", key];
                if ([mutablePath containsString:template] && [obj isKindOfClass:[NSString class]]) {
                    NSString *replaceStr = (NSString *)obj;
                    mutablePath = [[mutablePath stringByReplacingOccurrencesOfString:template withString:replaceStr] mutableCopy];
                } else {
                    [mutableDic addEntriesFromDictionary:@{ key : obj}];
                }
            }];
        }
        NSURLComponents *component = [[NSURLComponents alloc] initWithString:mutablePath];
        NSMutableArray <NSURLQueryItem *> *queryMutableArray = [[NSMutableArray alloc] init];
        if (component.queryItems.count > 0) {
            [queryMutableArray addObjectsFromArray:component.queryItems];
        }
        if (queryMutableArray.count > 0) {
            component.queryItems = queryMutableArray;
        } else {
            component.queryItems = nil;
        }
        if (completeHandler) {
            completeHandler(component.URL.absoluteString, [SBasicRequestModel setBaseModel:mutableDic]);
        }
    }
}

+ (NSString *)md5:(NSString *)string {
    const char *cStr = [string UTF8String];
    //    unsigned char result[32];//32位
    unsigned char result[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];
}

+ (NSString *)cacheKeyWithPath:(NSString *)path {
    NSString *key;
    if (path.isNotBland) {
        key = [self md5:path];
    }
    return key;
}

+ (BOOL)validateResumeData:(NSData *)data {
    // From http://stackoverflow.com/a/22137510/3562486
    if (!data || [data length] < 1) return NO;
    
    NSError *error;
    NSDictionary *resumeDictionary = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
    if (!resumeDictionary || error) return NO;
    
    // Before iOS 9 & Mac OS X 10.11
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED < 90000)\
|| (defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED < 101100)
    NSString *localFilePath = [resumeDictionary objectForKey:@"NSURLSessionResumeInfoLocalPath"];
    if ([localFilePath length] < 1) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:localFilePath];
#endif
    // After iOS 9 we can not actually detects if the cache file exists. This plist file has a somehow
    // complicated structue. Besides, the plist structure is different between iOS 9 and iOS 10.
    // We can only assume that the plist being successfully parsed means the resume data is valid.
    return YES;
}

+ (NSString *)incompleteDownloadTempCacheFolder {
    NSFileManager *fileManager = [NSFileManager new];
    static NSString *cacheFolder;
    if (!cacheFolder) {
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:@"Incomplete"];
    }
    NSError *error = nil;
    if(![fileManager createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        cacheFolder = nil;
    }
    return cacheFolder;
}

+ (NSURL *)incompleteDownloadTempPathForDownloadPath:(NSString *)downloadPath {
    NSString *tempPath = nil;
    NSString *md5URLString = [self md5:downloadPath];
    tempPath = [[self incompleteDownloadTempCacheFolder] stringByAppendingPathComponent:md5URLString];
    return [NSURL fileURLWithPath:tempPath];
}

+ (void)postDueNotification {
    RefreshTokenRetrySuccessTimes = 0;
    GlobalMuatableArray = [[NSMutableArray alloc] init];
    if (InBootPage) {
        [GSLETON newGSUser:[NSDictionary new]];
        [[NSNotificationCenter defaultCenter] postNotificationName:LOGIN_PAST_DUE_NOTIFICATION object:@""];
    } else {
        [KSAlertView showWithTitle:@"校验失败，请重新登录"
                           message:nil
                       buttonTitle:@"确定"
                        buttonType:MMAlertButtonTypeNormal
                          tapBlock:^{
            [GSLETON newGSUser:[NSDictionary new]];
            [[NSNotificationCenter defaultCenter] postNotificationName:LOGIN_PAST_DUE_NOTIFICATION object:@""];
        }];
    }
}

+ (void)updateWithResponse:(id)object {
    SBasicResponseModel *response = [[SBasicResponseModel alloc] initWithDictionary:object];
    if ([response.code integerValue] == 999999){
        [self postDueNotification];
    } else {
        if (response.state == NO && response.type == 1) {
            [[[UIApplication sharedApplication] getTopNavigationController].topViewController hideToast];
            [GSCommonUtil showUpdateAppAlertWithMessage:response.msg];
        }
    }
}

+ (NSString *)cacheLocalPathWithUrl:(NSString *)url {
    NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    //拼接文件全路径
    NSString *fullpath = [caches stringByAppendingPathComponent:[self md5:url]];
    return fullpath;
}

+ (GSHTTPSessionManager *)sessionWithRequest:(GSHTTPReqeust *)request {
    GSHTTPSessionManager *session = [GSHTTPSessionManager sharedSessionWithUrl:BaseUrl];
    if (request.isJson && request.methodType == GSRequestMethodTypePost) {
        session.requestSerializer = [AFJSONRequestSerializer serializer];
    } else {
        session.requestSerializer = [AFHTTPRequestSerializer serializer];
        session.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        [session.requestSerializer setQueryStringSerializationWithBlock:^NSString * _Nonnull(NSURLRequest * _Nonnull request, id  _Nonnull parameters, NSError * _Nullable __autoreleasing * _Nullable error) {
            NSDictionary<NSString *, NSString *> *parms = (NSDictionary *)parameters;
            NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
            [parms enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
                [mutableArray addObject:[NSString stringWithFormat:@"%@=%@",key, obj]];
            }];
            NSString *query = [mutableArray componentsJoinedByString:@"&"];
            return query;
        }];
    }
    session.requestSerializer.timeoutInterval = 15;
    #if DEBUG
    BOOL disableGrey = [self disableGrey];
    if (!disableGrey) {
        [session.requestSerializer setValue:@"true" forHTTPHeaderField:@"grey"];
    }
    #endif
//    NSString *authStr;
//    if ([GSSerSingleton shareSingleton].tokenModel.accessToken.isNotBland && !request.isUpateRefreshToken) {
//        authStr = [NSString stringWithFormat:@"%@ %@", [GSSerSingleton shareSingleton].tokenModel.tokenType,  [GSSerSingleton shareSingleton].tokenModel.accessToken];
//    } else {
//        authStr = [[NSString stringWithFormat:@"%@:%@", KClientId, KClientSecret] base64String];
//        authStr = [NSString stringWithFormat:@"Basic %@", authStr];
//    }
//    [session.requestSerializer setValue:authStr forHTTPHeaderField:@"Authorization"];
    return session;
}

@end


