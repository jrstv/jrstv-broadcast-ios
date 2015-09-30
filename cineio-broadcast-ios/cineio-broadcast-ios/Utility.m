//
//  Utility.m
//  games
//
//  Created by xuesai on 12-10-30.
//
//

#import "Utility.h"

@implementation Utility

+ (NSString*)version {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

@end








