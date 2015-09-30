//
//  Global.h
//
//
#import <UIKit/UIScreen.h>
#import <UIKit/UIKit.h>

extern NSString * connectHost;
extern NSString * kPlatfromNumber;
extern NSString * kPushDataUserNotify;
extern NSString * kNickName;

#define SCREEN_WIDTH          ([UIScreen mainScreen].bounds.size.width)
#define SCREEN_HEIGHT         ([UIScreen mainScreen].bounds.size.height)

#define USER_DEFAULT          [NSUserDefaults standardUserDefaults]

#define iPhone4     ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 960), [[UIScreen mainScreen] currentMode].size) : NO)
#define iPhone5     ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 1136), [[UIScreen mainScreen] currentMode].size) : NO)
#define iPhone6     ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(750, 1334), [[UIScreen mainScreen] currentMode].size) : NO)
#define iPhone6Plus ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2208), [[UIScreen mainScreen] currentMode].size) : NO)

//use dlog to print while in debug model
#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif
