//
//  CineBroadcasterViewController.h
//  Broadcaster
//
//  Created by Jeffrey Wescott on 6/4/14.
//  Copyright (c) 2014 cine.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CineBroadcasterProtocol.h"
#import "CineBroadcasterView.h"

#import "HPVideoBarrageViewController.h"

@interface CineBroadcasterViewController : UIViewController <CineBroadcasterProtocol>
{
    
}

- (void)toggleStreaming:(id)sender;
- (void)updateStatus:(NSString *)message;
- (void)enableControls;

@property (nonatomic, strong) HPVideoBarrageViewController *barrageViewController;

@property (nonatomic, strong) NSString* roomId;
@property (nonatomic, strong) NSString* password;

@property (nonatomic, strong) UIButton *popTextButton;

@end


/*
 Fix NSTimer strong reference problem
 */
@interface WeakTimerTarget : NSObject

@property (nonatomic, weak) id target;

- (void) timerFire:(NSTimer *)timer;

@end
