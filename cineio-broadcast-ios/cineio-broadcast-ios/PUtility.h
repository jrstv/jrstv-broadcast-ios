//
//  PUtility.h
//  Example
//
//  Created by 施灵凯 on 15/9/24.
//  Copyright © 2015年 cine.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PUtility : NSObject

+ (NSString *)getStringElementForKey:(id)key fromDict:(NSDictionary *)dict;


+ (id)systemFontSize:(NSInteger)fontSize;

+ (NSArray *)convertJSONToArray:(NSString *)string;

#pragma mark - 根据16进制获取UIColor
+ (UIColor *)getColorByHexadecimalColor:(NSString *)hexColor;

@end
