//
//  HPVideoBarrageViewController.h
//  games
//
//  Created by Wusicong on 15/2/2.
//
//

#import <UIKit/UIKit.h>

@interface HPVideoBarrageViewController : UIViewController
@property (nonatomic,assign)BOOL isEnableBarragel;

- (void)addMsg:(NSDictionary *)msgDic isFirstIndex:(BOOL)isFirst isSelfSend:(BOOL)isSelfSend;
//- (void)pushMsgForSelf:(NSString*)msg; //本地弹幕发送调用

- (void)pauseAnimation;
- (void)continueAnimation; //弹幕动画暂停、继续

- (void)stopMessage;
- (void)restartMessage;

- (void)cleanMsgs; //清除当前缓存的弹幕数据

@end
