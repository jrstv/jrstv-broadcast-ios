//
//  PUtility.m
//  Example
//
//  Created by 施灵凯 on 15/9/24.
//  Copyright © 2015年 cine.io. All rights reserved.
//

#import "PUtility.h"
#import "Global.h"

@implementation PUtility

+ (NSString *)getStringElementForKey:(id)key fromDict:(NSDictionary *)dict {
    if(![dict isKindOfClass:[NSDictionary class]])
        return @"";
    
    NSString *result = @"";
    id value = [dict objectForKey:key];
    if (value) {
        if ([value isKindOfClass:[NSString class]]) {
            result = value;
        } else if ([value isKindOfClass:[NSNumber class]]) {
            result = [(NSNumber *)value stringValue];
        }
    }
    return result;
    
}

+ (id)systemFontSize:(NSInteger)fontSize {
    if (iPhone6Plus) {
        return [UIFont systemFontOfSize:fontSize+2];
    }else{
        return [UIFont systemFontOfSize:fontSize];
    }
}

+ (NSArray *)convertJSONToArray:(NSString *)string {
    NSError *error = nil;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (!data || data == nil) {
        return nil;
    }
    NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (nil == error){
        return array;
    }else{
        return nil;
    }
}

#pragma mark - 根据16进制获取UIColor
+ (UIColor *)getColorByHexadecimalColor:(NSString *)hexColor {
    unsigned int redInt_, greenInt_, blueInt_;
    NSRange rangeNSRange_;
    rangeNSRange_.length = 2;  // 范围长度为2
    
    // 取红色的值
    rangeNSRange_.location = 0;
    [[NSScanner scannerWithString:[hexColor substringWithRange:rangeNSRange_]] scanHexInt:&redInt_];
    
    // 取绿色的值
    rangeNSRange_.location = 2;
    [[NSScanner scannerWithString:[hexColor substringWithRange:rangeNSRange_]] scanHexInt:&greenInt_];
    
    // 取蓝色的值
    rangeNSRange_.location = 4;
    [[NSScanner scannerWithString:[hexColor substringWithRange:rangeNSRange_]] scanHexInt:&blueInt_];
    
    return [UIColor colorWithRed:(float)(redInt_/255.0f) green:(float)(greenInt_/255.0f) blue:(float)(blueInt_/255.0f) alpha:1.0f];
    
}

@end
