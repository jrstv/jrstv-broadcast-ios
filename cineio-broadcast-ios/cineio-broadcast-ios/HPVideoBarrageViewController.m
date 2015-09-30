//
//  HPVideoBarrageViewController.m
//  games
//
//  Created by Wusicong on 15/2/2.
//
//

#import "HPVideoBarrageViewController.h"
#import "NSDictionary+Additions.h"
#import "Global.h"
#import "PUtility.h"

#define BA_LINENUM  5
#define BA_OriginY  (43+20) //default sticky view height
#define BA_MAX_BARRAGE_COUNT 50

@interface HPVideoBarrageViewController ()

@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, strong) NSTimer        *timer;
@property (nonatomic, strong) NSTimer        *testTimer;//本地测试弹幕用计时器

@property NSInteger barrageIndex;
@end



@implementation HPVideoBarrageViewController


- (void)dealloc {
    if (self.timer) {
        if ([self.timer isValid]) {
            [self.timer invalidate];
        }
        self.timer = nil;
    }
    if (self.testTimer) {
        if ([self.testTimer isValid]) {
            [self.testTimer invalidate];
        }
        self.testTimer = nil;
    }
    DLog(@"dealloc HPVideoBarrageViewController");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _isEnableBarragel = YES;
    [self initUI];
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - Private Method

- (void)initUI {
    self.messageQueue = [NSMutableArray array];
    self.barrageIndex = 0;
    
    [self restartMessage];
    
    //本地测试时，往队列手动添加弹幕
//    self.testTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(pushMsg) userInfo:nil repeats:YES];
}

#pragma mark - Public Method

- (void)addMsg:(NSDictionary *)msgDic isFirstIndex:(BOOL)isFirst isSelfSend:(BOOL)isSelfSend {
    NSString *color = @"ffffff";
    if ([msgDic objectForKey:@"gift"] && [[msgDic objectForKey:@"gift"]isKindOfClass:[NSDictionary class]]) {
        if ([[[msgDic objectForKey:@"gift"]stringValueForKey:@"link_color"]length]) {
            color = [[msgDic objectForKey:@"gift"]stringValueForKey:@"link_color"];
        }
    }
    if (isFirst) {
        if ([[msgDic stringValueForKey:@"content"]length]) {
            [self pushMsgForSelf:[msgDic stringValueForKey:@"content"] andColor:color isSelfSend:isSelfSend];
        }
    } else {
//        if (self.messageQueue.count > BA_MAX_BARRAGE_COUNT) { //如果当前弹幕数量超出某个临界点，则丢弃该弹幕
//            return;
//        }
        if ([[msgDic stringValueForKey:@"content"]length]){
            [self pushMsg:[NSString stringWithFormat:@"%@",[msgDic stringValueForKey:@"content"]] color:color];
        }
    }
}

- (void)cleanMsgs {
    [self.messageQueue removeAllObjects];
}

#pragma mark -
#pragma mark - Message method

- (void)stopMessage {
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
}

- (void)restartMessage {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:[self getBA_INTERVAL] target:self selector:@selector(displayMessage) userInfo:nil repeats:YES];
}

#pragma mark -
#pragma mark - Animation method
- (void)pauseAnimation {
    [self stopMessage];
    for (UIView *view in self.view.subviews) {
        [self pauseLayer:view.layer];
    }
}

- (void)continueAnimation {
    [self restartMessage];
    for (UIView *view in self.view.subviews) {
        [self resumeLayer:view.layer];
    }
}

- (void)pauseLayer:(CALayer*)layer {
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
}

//继续layer上面的动画
- (void)resumeLayer:(CALayer*)layer {
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
}

#pragma mark - Message Queue

- (void)pushMsg {
    [self pushMsg:@"hahahahahahahaha" color:@"ffffff"];
}

- (void)pushMsg:(NSString*)msg color:(NSString *)color{
    NSDictionary *content = @{@"Text"   :msg?:@" ",
                              @"board"  :@"0",
                              @"color"  :color?:@"ffffff"
                              };
    NSArray *args = @[content];
    NSDictionary *dict = @{@"args":args};
    [self.messageQueue addObject:dict];
}

//本地显示发送的弹幕
- (void)pushMsgForSelf:(NSString*)msg andColor:(NSString *)color isSelfSend:(BOOL)isSelfSend{
    
    NSDictionary *content = nil;
    if (isSelfSend) {
        content = @{@"Text"   :msg?:@" ",
                    @"board"  :@"1",
                    @"color"  :color?:@"ffffff"
                    };
    }else {
        content = @{@"Text"   :msg?:@" ",
                    @"board"  :@"0",
                    @"color"  :color?:@"ffffff"
                    };
    }
    NSArray *args = @[content];
    NSDictionary *dict = @{@"args":args};
    [self.messageQueue insertObject:dict atIndex:0];
}

- (NSDictionary*)popMsg {
    if (self.messageQueue.count > 0) {
        NSDictionary *args = [self.messageQueue[0] objectForKey:@"args"][0];
        [self.messageQueue removeObjectAtIndex:0];
        return args;
    }
    return nil;
}

- (void)displayMessage{
    NSDictionary *args = [self popMsg];
    NSString *popMsg = [args objectForKey:@"Text"];
    BOOL board = [[args objectForKey:@"board"] boolValue];
    
    if (!_isEnableBarragel) {
        return;
    }
    if (popMsg) {
        CGFloat screenWidth = MAX(SCREEN_WIDTH, SCREEN_HEIGHT);
        CGFloat labelHeight = 20;
        CGSize size = [popMsg sizeWithAttributes:@{NSFontAttributeName:[PUtility systemFontSize:18]}];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(screenWidth, BA_OriginY + [self getBarrageIndex] * labelHeight, size.width, labelHeight)];
            label.text = popMsg;
            label.font = [PUtility systemFontSize:18];
            label.shadowColor = [UIColor blackColor];
            label.shadowOffset = CGSizeMake(0, 1);
            label.textColor = [PUtility getColorByHexadecimalColor:args[@"color"]];
            [self.view addSubview:label];
            //自己发言，加入下划线
            if (board) {
                //add line
                UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, label.frame.size.height - 0.5, label.frame.size.width, 0.5)];
                line.backgroundColor = [UIColor whiteColor];
                [label addSubview:line];
            }
            
            NSInteger animationTime = [self getBarrageTimeWithLabel:label];
            [UIView animateWithDuration:animationTime delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                [self change:label originX:-screenWidth];
            } completion:^(BOOL finished) {
                [label removeFromSuperview];
            }];
            
        });
    }
}

- (void)change:(UIView *)view originX:(CGFloat)originX {
    CGRect frame = view.frame;
    frame.origin.x = originX;
    view.frame = frame;
}

- (NSInteger)getBarrageIndex {
//    self.barrageIndex = (arc4random()%BA_LINENUM);
    
    self.barrageIndex ++; //按顺序排布弹幕显示
    if (self.barrageIndex > BA_LINENUM) {
        self.barrageIndex = 0;
    }
    
    return self.barrageIndex;
}

//根据label的内容换算弹幕的滚动时间
- (NSInteger)getBarrageTimeWithLabel:(UILabel *)label {
    
    NSInteger time = (arc4random()%2 + 10) + sqrt(label.text.length);
    
    DLog(@"弹幕时间---time [%ld] length[%lu]", (long)time, (unsigned long)label.text.length);
    
    return time; //随机产生5到15秒的弹幕动画时间
}

- (CGFloat)getBA_INTERVAL {
    CGFloat intervalTime = 1.5;
    
    if (iPhone4) {
        intervalTime = 2; //适配3.5寸设备的弹幕重叠问题
    }
    
    return intervalTime;
}

@end
