//
//  Global.m
//

#import "Global.h"

#define envType            0

//production 生产环境
#if (envType == 0)
NSString *connectHost      = @"http://games.mobileapi.hupu.com/";
//test 测试环境
#elif (envType == 1)
NSString *connectHost      = @"http://test.mobileapi.hupu.com/";
#endif

NSString * kPlatfromNumber    = @"3";

NSString *kPushDataUserNotify                                  = @"kPushDataUserNotify";

NSString *kNickName            = @"nickname";
