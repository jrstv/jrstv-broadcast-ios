//
//  CineBroadcasterViewController.m
//  Broadcaster
//
//  Created by Jeffrey Wescott on 6/4/14.
//  Copyright (c) 2014 cine.io. All rights reserved.
//

#import "CineBroadcasterViewController.h"
#import <AVFoundation/AVFoundation.h>

#import "GlobalWebSocketManager.h"
#import "Global.h"
#import "NSDictionary+Additions.h"
#import "PUtility.h"

#import "ASIHTTPRequest.h"

#pragma mark - CineBroadcasterViewController

@interface CineBroadcasterViewController () <VCSessionDelegate,GlobalWebSocketManagerDelegate, ASIHTTPRequestDelegate>
{
    CineBroadcasterView *_broadcasterView;
    BOOL _orientationLocked;
    CGSize _videoSize;
    int _videoBitRate;
    int _framesPerSecond;
    float _sampleRateInHz;
    BOOL _torchOn;
    CineCameraState _cameraState;
    
    //for Barrage
    NSString *_enName;
    NSString *_gid;
    NSString *_lastPid;
    NSString *_en;
    
    BOOL isGotRoomInfo;
    
    NSInteger _nextPageStartPid;
    NSInteger _currentMaxPid;
    NSInteger _currentMinPid;
    
    BOOL _hasMore;
    
    NSMutableArray *_chatConentsArray;      //直播聊天内容
    
    BOOL _isPopTextEnable;
}

@property (nonatomic, strong) VCSimpleSession* session;
@property (nonatomic, strong) WeakTimerTarget *weakTarget;
@property (atomic, strong) NSTimer *reconnectTimer;

@end

@implementation CineBroadcasterViewController

// managed by us
@synthesize publishUrl;
@synthesize publishStreamName;
@synthesize danmu;

@synthesize popTextButton;

// managed by us (and we'll keep in sync w/ VCSimpleSession)
@dynamic orientationLocked;
@dynamic videoSize;
@dynamic videoBitRate;
@dynamic framesPerSecond;
@dynamic sampleRateInHz;
@dynamic torchOn;
@dynamic cameraState;
@dynamic streamState;

- (void)viewDidLoad
{
    [super viewDidLoad];

    _session = [[VCSimpleSession alloc] initWithVideoSize:self.videoSize frameRate:self.framesPerSecond bitrate:self.videoBitRate useInterfaceOrientation:NO];
    //_session.useAdaptiveBitrate = YES; // this seems to crash VideoCore
    
    _weakTarget = [[WeakTimerTarget alloc] init];
    _weakTarget.target = self;

    _broadcasterView = (CineBroadcasterView *)self.view;
    _broadcasterView.orientationLocked = _session.orientationLocked = self.orientationLocked;
    [_broadcasterView.controlsView.recordButton.button addTarget:self action:@selector(toggleStreaming:) forControlEvents:UIControlEventTouchUpInside];
    [_broadcasterView.controlsView.torchButton addTarget:self action:@selector(toggleTorch:) forControlEvents:UIControlEventTouchUpInside];
    [_broadcasterView.controlsView.cameraStateButton addTarget:self action:@selector(toggleCameraState:) forControlEvents:UIControlEventTouchUpInside];
    
    
    [_broadcasterView.cameraView addSubview:_session.previewView];
    _session.previewView.frame = _broadcasterView.bounds;
    _session.delegate = self;
    
    
    // Danmaku support
    double rotation = [self rotationForOrientation:UIDeviceOrientationLandscapeLeft];
    CGAffineTransform transform = CGAffineTransformMakeRotation(rotation);

    self.barrageViewController.isEnableBarragel = YES;
    self.barrageViewController.view.hidden = NO;
    self.barrageViewController.view.transform = transform;
    [self.view addSubview:self.barrageViewController.view];

    _isPopTextEnable = YES;
    popTextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    popTextButton.frame = CGRectMake(12, 25, 40, 40);
    popTextButton.transform = transform;
    
    if (!_isPopTextEnable) {
        [popTextButton setImage:[UIImage imageNamed:@"barrage_close_btn"]  forState:UIControlStateNormal];
        [popTextButton setImage:[UIImage imageNamed:@"barrage_close_btn_1"]  forState:UIControlStateHighlighted];
    } else {
        [popTextButton setImage:[UIImage imageNamed:@"barrage_btn"]  forState:UIControlStateNormal];
        [popTextButton setImage:[UIImage imageNamed:@"barrage_btn_1"]  forState:UIControlStateHighlighted];
    }
    
    [popTextButton addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:popTextButton];
    
    //test param
//    _enName = @"NBA";
//    _gid = @"10001412";
//    _lastPid = @"0";
//    _roomId = @"3";
    
    _enName = @"";
    _gid = @"";
    _lastPid = @"0";
    _en=@"";
    
    isGotRoomInfo = NO;
}

- (double)rotationForOrientation:(UIDeviceOrientation)orientation
{
    if (self.orientationLocked) return 0;
    
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            return 0;
        case UIDeviceOrientationPortraitUpsideDown:
            return M_PI;
        case UIDeviceOrientationLandscapeLeft:
            return M_PI_2;
        case UIDeviceOrientationLandscapeRight:
            return -M_PI_2;
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationUnknown:
        default:
            return 0;
    }
}

- (void)buttonClick:(UIButton *)sender
{
    _isPopTextEnable = !_isPopTextEnable;
    if (!_isPopTextEnable) {
        [popTextButton setImage:[UIImage imageNamed:@"barrage_close_btn"]  forState:UIControlStateNormal];
        [popTextButton setImage:[UIImage imageNamed:@"barrage_close_btn_1"]  forState:UIControlStateHighlighted];
    } else {
        [popTextButton setImage:[UIImage imageNamed:@"barrage_btn"]  forState:UIControlStateNormal];
        [popTextButton setImage:[UIImage imageNamed:@"barrage_btn_1"]  forState:UIControlStateHighlighted];
    }
    [self enableTextBarrages:_isPopTextEnable];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self registerApplicationObservers];
    
    if (!self.orientationLocked) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:NSSelectorFromString(@"orientationChanged") name:UIDeviceOrientationDidChangeNotification object:nil];

        if ([self.view isKindOfClass:[CineBroadcasterView class]]) {
            CineBroadcasterView *cbView = (CineBroadcasterView *)self.view;
            if ([cbView respondsToSelector:NSSelectorFromString(@"orientationChanged")]) {
                [[NSNotificationCenter defaultCenter] addObserver:(cbView) selector:NSSelectorFromString(@"orientationChanged") name:UIDeviceOrientationDidChangeNotification object:nil];
            }
            if ([cbView.controlsView respondsToSelector:NSSelectorFromString(@"orientationChanged")]) {
                [[NSNotificationCenter defaultCenter] addObserver:(cbView.controlsView) selector:NSSelectorFromString(@"orientationChanged") name:UIDeviceOrientationDidChangeNotification object:nil];
            }
        }
    }
    
    [[GlobalWebSocketManager sharedInstance]setDelegate:self type:DelegateType_chat_casino];
    
    if (isGotRoomInfo) {
        [self joinRoom];
    }else {
        NSString *urlStr = [NSString stringWithFormat:@"%@room/getPlaybyplay?roomid=%@&client=x", connectHost, _roomId];
        ASIHTTPRequest *request = [ ASIHTTPRequest requestWithURL :[NSURL URLWithString:urlStr]];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}

- (void)orientationChanged
{
    if (self.orientationLocked) return;
    
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    double rotation = 0;
    
    switch (orientation) {
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
            return;
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
            rotation = [self rotationForOrientation:orientation];
            break;
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationUnknown:
        default:
            return;
    }
    
    CGAffineTransform transform = CGAffineTransformMakeRotation(rotation);
    
    [UIView animateWithDuration:0.4
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.barrageViewController.view.transform = transform;
                         self.popTextButton.transform = transform;
                     }
                     completion:nil];
}


- ( void )requestFinished:( ASIHTTPRequest *)request
{
    NSError *errorJson;
    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:[request responseData]
                                                         options:NSJSONReadingMutableContainers
                                                           error:&errorJson];
    if (!errorJson && data) {
        NSDictionary *result = [data objectForKey:@"result"];
        
        NSInteger _lid = [result intValueForKey:@"lid"];
        _gid = [PUtility getStringElementForKey:@"gid" fromDict:result];
        
        _en = [PUtility getStringElementForKey:@"en" fromDict:result];
        
        switch (_lid) {
            case 1:
                _enName = @"NBA";
                break;
            case 2:
                _enName = @"CBA";
                break;
            case 3:
                _enName = @"中超";
                break;
            case 4:
                _enName = @"欧冠";
                break;
            case 5:
                _enName = @"英超";
                break;
            case 6:
                _enName = @"西甲";
                break;
            case 7:
                _enName = @"意甲";
                break;
            case 8:
                _enName = @"德甲";
                break;
            case 9:
                _enName = @"法甲";
                break;
            case 10:
                _enName = @"世界杯";
                break;
            case 11:
                _enName = @"其他";
                break;
            case 12:
                _enName = @"国际足球";
                break;
            default:
                break;
        }
        
        if (_lid>=1&&_lid<=12&&![_gid isEqualToString:@""]&&![_en isEqualToString:@""]) {
            isGotRoomInfo = YES;
        }
        
        if (isGotRoomInfo) {
            [self joinRoom];
        }
    }
}

- ( void )requestFailed:( ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog ( @"requestFailed:%@" ,error. userInfo );
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if ([self.view isKindOfClass:[CineBroadcasterView class]]) {
        CineBroadcasterView *cbView = (CineBroadcasterView *)self.view;
        [[NSNotificationCenter defaultCenter] removeObserver:cbView name:UIDeviceOrientationDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:cbView.controlsView name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    [self unregisterApplicationObservers];

    [self.barrageViewController cleanMsgs]; //退到后台，清除当前缓存的弹幕数据
    
    [[GlobalWebSocketManager sharedInstance]setDelegate:nil type:DelegateType_chat_casino];
    [[GlobalWebSocketManager sharedInstance] leaveRoom];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (BOOL) prefersStatusBarHidden {
    return YES;
}

- (BOOL)orientationLocked
{
    return _orientationLocked;
}

- (void)setOrientationLocked:(BOOL)orientationLocked
{
    _broadcasterView.orientationLocked = _orientationLocked = orientationLocked;
}

- (CGSize)videoSize
{
    return _videoSize;
}

- (void)setVideoSize:(CGSize)videoSize
{
    _session.videoSize = _videoSize = videoSize;
}

- (int)videoBitRate
{
    return _videoBitRate;
}

- (void)setVideoBitRate:(int)videoBitRate
{
    _session.bitrate = _videoBitRate = videoBitRate;
}

- (int)framesPerSecond
{
    return _framesPerSecond;
}

- (void)setFramesPerSecond:(int)framesPerSecond
{
    _session.fps = _framesPerSecond = framesPerSecond;
}

- (float)sampleRateInHz
{
    return _sampleRateInHz;
}

- (void)setSampleRateInHz:(float)sampleRateInHz
{
    _session.audioSampleRate = _sampleRateInHz = sampleRateInHz;
}

- (BOOL)torchOn
{
    return _torchOn;
}

- (void)setTorchOn:(BOOL)isOn
{
    _session.torch = _torchOn = isOn;
}

- (CineCameraState)cameraState
{
    return _cameraState;
}

- (void)setCameraState:(CineCameraState)cameraState
{
    _cameraState = cameraState;
    _session.cameraState = (VCCameraState)_cameraState;
    _broadcasterView.cameraMirrored = (cameraState == CineCameraStateFront);
}

- (CineStreamState)streamState
{
    if (self.reconnectTimer)
        return CineStreamStateStarting;
    else
        return (CineStreamState)_session.rtmpSessionState;
}

- (void)toggleTorch:(id)sender {
    if (self.torchOn) {
        self.torchOn = NO;
    } else {
        self.torchOn = YES;
    }
}

- (void)toggleCameraState:(id)sender {
    if (self.cameraState == CineCameraStateFront) {
        self.cameraState = CineCameraStateBack;
    } else {
        self.cameraState = CineCameraStateFront;
    }
}

- (void)toggleStreaming:(id)sender
{
    NSLog(@"record / stop button touched");

    if (self.reconnectTimer) {
        _broadcasterView.controlsView.recordButton.recording = NO;
        [self updateStatus:@"Disconnected"];
        [self.reconnectTimer invalidate];
        self.reconnectTimer = nil;
        return;
    }

    switch(_session.rtmpSessionState) {
        case VCSessionStateNone:
        case VCSessionStatePreviewStarted:
        case VCSessionStateEnded:
        case VCSessionStateError:
            [_session startRtmpSessionWithURL:self.publishUrl andStreamKey:self.publishStreamName];
            break;
        default:
            [self updateStatus:@"Stopping..."];
            [_session endRtmpSession];
            
            [[GlobalWebSocketManager sharedInstance]setDelegate:nil type:DelegateType_chat_casino];
            break;
    }
}

- (void)updateStatus:(NSString *)message
{
    NSLog(@"%@", message);
    _broadcasterView.status.text = message;
}

- (void)enableControls
{
    _broadcasterView.controlsView.recordButton.enabled = YES;
    [self updateStatus:@"Ready"];
}

- (void) connectionStatusChanged:(VCSessionState)state
{
    switch(state) {
        case VCSessionStateStarting:
            _broadcasterView.controlsView.recordButton.recording = YES;
            [self updateStatus:@"Connecting to server..."];
            break;
        case VCSessionStateStarted:
            [self updateStatus:@"Streaming..."];
            break;
        case VCSessionStateEnded:
            if (!self.reconnectTimer) {
                _broadcasterView.controlsView.recordButton.recording = NO;
                [self updateStatus:@"Disconnected"];
            }
            break;
        case VCSessionStateError:
            if (!self.reconnectTimer) {
                [self updateStatus:@"Error, auto reconnecting..."];
                self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:3.0f
                                                                       target:_weakTarget
                                                                     selector:@selector(timerFire:)
                                                                     userInfo:nil
                                                                      repeats:NO];
            }
            break;
        default:
            break;
    }
}

- (void) autoReconnect:(id)sender {
    self.reconnectTimer = nil;

    switch(_session.rtmpSessionState) {
        case VCSessionStateNone:
        case VCSessionStatePreviewStarted:
        case VCSessionStateEnded:
        case VCSessionStateError:
            [_session startRtmpSessionWithURL:self.publishUrl andStreamKey:self.publishStreamName];
            break;
        default:
            break;
    }
}

#pragma mark - join

- (void)joinRoom
{
//    [[GlobalWebSocketManager sharedInstance] joinRoomChatWithType:_enName gid:_gid pid:_lastPid direc:@"next" withRoomId:_roomId];
    [[GlobalWebSocketManager sharedInstance] joinRoomChatWithType:_en gid:_gid pid:_lastPid direc:@"next" withRoomId:_roomId];
}

- (void)loadMore {
//    [[GlobalWebSocketManager sharedInstance] joinRoomChatWithType:_enName gid:_gid
    [[GlobalWebSocketManager sharedInstance] joinRoomChatWithType:_en gid:_gid
                                                              pid:[NSString stringWithFormat:@"%ld", (long)_nextPageStartPid]
                                                            direc:@"prev"
                                                       withRoomId:_roomId];
}

#pragma mark - GlobalWebSocketManagerDelegate

-(void)socketConnectFailed
{
    NSLog(@"socketConnectFailed");
    
    //todo showPopupMessage
}

-(void)handleSocketNotification:(NSDictionary *)jsonData
{
    
    NSDictionary *_item;
    NSDictionary *_result;
    
    __block NSArray *_data;
    __block NSString *_onLineString;
    __block NSString *_direc;
    __block NSString *_dataPid;
    
    _item = jsonData;
    DLog(@"_item chat:%@", _item);
    
    if (!_item || ![_item isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    //put here in case result is empty or nil
    //room_live_type 房间直播类型  -1 文字休息  -2视频休息 1文字2视频（join时会给出该字段，用于渲染文字或视频的切换）
    if ([_item intValueForKey:@"room_live_type"] == -2) {
    }else if ([_item intValueForKey:@"room_live_type"] == 2) {
    }
    
    //room_live_type 房间直播类型  -1 文字休息  -2视频休息 1文字2视频（join时会给出该字段，用于渲染文字或视频的切换）
    if (([_item intValueForKey:@"room_live_type"] == -1) || ([_item intValueForKey:@"room_live_type"] == 1)) {
        //视频转文字
    }
    
    if (![_item objectForKey:@"result"] || [[_item objectForKey:@"result"]isKindOfClass:[NSNull class]]) {
        return;
    }
    
    @synchronized(self){
        _result = [_item objectForKey:@"result"];
        
        //alert_type 弹窗类型 1：文字转视频，2：视频转文字，3：视频开启直播 4关闭视频   弹窗字段（只有在切换直播类型时，推送）
        if ([_result intValueForKey:@"alert_type"] == 2) {
            
        }else if ([_result intValueForKey:@"alert_type"] == 3) {
            
        }else if ([_result intValueForKey:@"alert_type"] == 4) {
            
        }
        
        // Show the casino notification window
        NSDictionary *casinoInfo = [_result objectForKey:@"casino"];
        if ([casinoInfo isKindOfClass:[NSDictionary class]] ) {
        }
        
        //礼品数量更新
        if ([_result objectForKey:@"gift_update"] && ![[_result objectForKey:@"gift_update"] isKindOfClass:[NSNull class]]) {
        }
        //房间状态更新
        //切换比赛通知，此字段只有在房间切换比赛时才会存在
        
        //sticky
        if ([_result objectForKey:@"chat_top"] && [[_result objectForKey:@"chat_top"] isKindOfClass:[NSDictionary class]]) {
            
        }
        
        if (![_result objectForKey:@"data"] || ![[_result objectForKey:@"data"] isKindOfClass:[NSArray class]]) {
            _data = [NSArray arrayWithObjects:nil];
        }else {
            _data = [_result objectForKey:@"data"];
        }
        
        _onLineString = [_item stringValueForKey:@"online"];
        
        _direc = [_item objectForKey:@"direc"];
        _dataPid = [_item stringValueForKey:@"pid"];
        
        if ([_direc isEqualToString:@"next"]) {
            if ([_dataPid integerValue] <= _currentMaxPid) {
                return;
            }else {
                _currentMaxPid = [_dataPid integerValue];
            }
        }else {
            if (([_dataPid integerValue] >= _currentMinPid) && _currentMinPid) {
                return;
            }else {
                _currentMinPid = [_dataPid integerValue];
            }
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //opearting contentArray
            if ([_direc isEqualToString:@"next"]){
                if ([_dataPid integerValue] > [_lastPid integerValue]) {
                    _lastPid = _dataPid;
                }else {
                    return;
                }
            }
            
            if (_nextPageStartPid == 0) {
                _nextPageStartPid = [_dataPid intValue] - [_data count] - 1;
            }
            
            if ([_direc isEqualToString:@"next"]) {
                [self appendChatContent:_data];
            }else {
                //加载更多,过滤掉空的数据
                [self appendMoreChatContent:_data];
                _nextPageStartPid -= [_data count];
            }
            if (_nextPageStartPid < 0) {
                _nextPageStartPid = 0;
            }
            _hasMore = _nextPageStartPid > 0;
        });
    }
}

-(void)rejoinIfLostConnect
{
//    [[GlobalWebSocketManager sharedInstance] joinRoomChatWithType:_enName gid:_gid pid:_lastPid direc:@"next" withRoomId:_roomId];
    [[GlobalWebSocketManager sharedInstance] joinRoomChatWithType:_en gid:_gid pid:_lastPid direc:@"next" withRoomId:_roomId];
}

/**
 *  追加长连接推的数据
 *  @param dataArray
 */
- (BOOL)appendChatContent:(NSArray *)dataArray
{
    BOOL isAddObjectInDataSource = NO;
    if (![dataArray isKindOfClass:[NSArray class]] || ![dataArray count]) {
        return isAddObjectInDataSource;
    }
    for (NSInteger i = dataArray.count - 1; i >= 0; i--) {
        NSDictionary *contentItem = dataArray[i];
        NSString *content = [PUtility getStringElementForKey:@"content" fromDict:contentItem];
        if ([content isKindOfClass:[NSString class]] && content.length > 0) {
            BOOL isRepeat = NO;
            if ([USER_DEFAULT objectForKey:kNickName] && _chatConentsArray.count < 20 && ![contentItem hasKey:@"gift"]) { //do not add repeat content
                for (NSDictionary *chatContent in _chatConentsArray) {
                    if ([[chatContent objectForKey:@"content"] isEqualToString:[contentItem objectForKey:@"content"]] &&
                        [[USER_DEFAULT objectForKey:kNickName] isEqualToString:[contentItem objectForKey:@"username"]]) {
                        isRepeat = YES;
                        break;
                    }
                }
            }
            if (!isRepeat) {
                [_chatConentsArray insertObject:contentItem atIndex:0];
                
                [self addBarrageData:contentItem atFirstIndex:YES isSelfSend:NO];
                
                if (!isAddObjectInDataSource) {
                    isAddObjectInDataSource = YES;
                }
            }
        }
    }
    return isAddObjectInDataSource;
}

- (BOOL)appendMoreChatContent:(NSArray *)dataArray
{
    BOOL isAddObjectInDataSource = NO;
    if (![dataArray isKindOfClass:[NSArray class]] || ![dataArray count]) {
        return isAddObjectInDataSource;
    }
    for (NSDictionary *contentItem in dataArray) {
        NSString *contentStr = [PUtility getStringElementForKey:@"content" fromDict:contentItem];
        if ([contentStr isKindOfClass:[NSString class]] && contentStr.length) {
            [_chatConentsArray addObject:contentItem];
            
            [self addBarrageData:contentItem atFirstIndex:NO isSelfSend:NO];
            
            if (!isAddObjectInDataSource) {
                isAddObjectInDataSource = YES;
            }
        }
    }
    return isAddObjectInDataSource;
}

- (HPVideoBarrageViewController *)barrageViewController {
    if (!_barrageViewController) {
        _barrageViewController = [[HPVideoBarrageViewController alloc] init];
    }
    return _barrageViewController;
}

- (void)addBarrageData:(NSDictionary *)dataDic atFirstIndex:(BOOL)isFirst isSelfSend:(BOOL)isSelfSend
{
    if (isFirst) {
        [self.barrageViewController addMsg:dataDic isFirstIndex:YES isSelfSend:isSelfSend];
    } else {
        [self.barrageViewController addMsg:dataDic isFirstIndex:NO isSelfSend:isSelfSend];
    }
}

- (void)enableTextBarrages:(BOOL)yesOrNO {
    //show or not show poptext
    if (yesOrNO == YES) {
        self.barrageViewController.view.alpha = 1;
        self.barrageViewController.isEnableBarragel = YES;
    } else {
        self.barrageViewController.view.alpha = 0;
        self.barrageViewController.isEnableBarragel = NO;
    }
}

#pragma mark app state changed

- (void)registerApplicationObservers
{
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
}

- (void)unregisterApplicationObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillTerminateNotification
                                                  object:nil];
}

- (void)applicationWillEnterForeground
{
    
}

- (void)applicationDidBecomeActive
{
    [[GlobalWebSocketManager sharedInstance]setDelegate:self type:DelegateType_chat_casino];
}

- (void)applicationWillResignActive
{
    
    [[GlobalWebSocketManager sharedInstance]setDelegate:nil type:DelegateType_chat_casino];
}

- (void)applicationDidEnterBackground
{
    
    [[GlobalWebSocketManager sharedInstance]leaveRoom];
    [[GlobalWebSocketManager sharedInstance].socketIO disconnect];
    DLog(@"=========程序进入后台了啊 请注意============");
}

- (void)applicationWillTerminate
{

}

@end

#pragma mark - WeakTimerTarget

@implementation WeakTimerTarget

- (void) timerFire:(NSTimer *)timer {
    [self.target performSelector:@selector(autoReconnect:) withObject:timer.userInfo];
}

@end