//
//  NSDictionary+Additions.m
//  games
//
//  Created by xuesai on 12-10-15.
//
//

#import "NSDictionary+Additions.h"

@implementation NSDictionary (Additions)

- (BOOL)hasKey:(NSString*)key {
    for (id k in [self allKeys]) {
        if ([k isEqualToString:key]) {
            return YES;
        }
    }
    return NO;  
}

- (NSInteger)intValueForKey:(NSString*)key {
    NSInteger result = 0;
    if (![self isKindOfClass:[NSDictionary class]]) {
        return result;
    }
    id value = [self objectForKey:key];
    if (value && [value isKindOfClass:[NSString class]]) {
      result = (NSInteger)[(NSString *)value longLongValue];
    } else if (value && [value isKindOfClass:[NSNumber class]]) {
      result = (NSInteger)[(NSNumber *)value longLongValue];
    }
    return result;
}

- (NSString *)stringValueForKey:(NSString*)key {
    NSString *result = @"";
    if (![self isKindOfClass:[NSDictionary class]]) {
        return result;
    }
    id value = [self objectForKey:key];
    if (value && [value isKindOfClass:[NSString class]]) {
        result = value;
    } else if (value && [value isKindOfClass:[NSNumber class]]) {
//        if ([(NSNumber *)value stringValue]) {
//            result = [(NSNumber *)value stringValue];
//        }
        result = [NSString stringWithFormat:@"%lld",[value longLongValue]];
    }
    return result;
}

@end
