//
//  GlobalWebSocketManager.m
//  games
//
//  Created by hupu on 14/11/14.
//
//

#import "GlobalWebSocketManager.h"
#import "Utility.h"
#import "Global.h"
#import "NSDictionary+Additions.h"

#import "ASIHTTPRequest.h"
#import "PUtility.h"

#define kSocketConnectMaxTryCount 3


@interface GlobalWebSocketManager () <ASIHTTPRequestDelegate> {
	NSTimer *_socketRetryTimer;
    BOOL isBackground;
}
@property (nonatomic, strong) NSDictionary *socket_emit_data;
@end



@implementation GlobalWebSocketManager

static GlobalWebSocketManager *SINGLETON = nil;

static bool isFirstAccess = YES;

#pragma mark - Public Method

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [self clearAllDelegate];

	if (_socketIO) {
		[_socketIO disconnect];
		_socketIO = nil;
	}

	if (_socketRetryTimer) {
		if ([_socketRetryTimer isValid]) {
			[_socketRetryTimer invalidate];
		}
		_socketRetryTimer = nil;
	}

	_socket_emit_data = nil;
	_ipAndPort = nil;
    _openUDID = nil;
    
    [self unregisterApplicationObservers];
}

+ (id)sharedInstance {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		isFirstAccess = NO;
		SINGLETON = [[super allocWithZone:NULL] init];
	});
    
    [SINGLETON registerApplicationObservers];

	return SINGLETON;
}

#pragma mark - socket io methods

- (void)reconnectAfterSomeTime {
	if (_socketRetryTimer) {
		if ([_socketRetryTimer isValid]) {
			[_socketRetryTimer invalidate];
		}
	}
	_socketRetryTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(connectSocket) userInfo:nil repeats:NO];

	DLog(@"socket try reconnect after 5 secs");
}

- (void)connectSocket {
	if (_socketRetryTimer) {
		if ([_socketRetryTimer isValid]) {
			[_socketRetryTimer invalidate];
		}
	}

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_socketIO = [[SocketIO alloc] initWithDelegate:self];
	});


	_tryFetchCount++;
	if (_tryFetchCount > kSocketConnectMaxTryCount) {
		_tryFetchCount = 0;
		if (!_socketIO.isConnected) {
			[self reRequestRedirector];
			return;
		}
	}

	if (!_socketIO.isConnected && !_socketIO.isConnecting) {
		if (_ipAndPort == nil) {
			[self reRequestRedirector];
		}else {
			[self connectSocketWithIpAndPort:_ipAndPort];
		}
	}
}

- (void)connectSocketWithIpAndPort:(NSString *)ipAndPort {
    NSRange range = [ipAndPort rangeOfString:@":"];
    NSString *ip = [ipAndPort substringToIndex:range.location];
    NSInteger port = [[ipAndPort substringFromIndex:range.location + 1] intValue];
    if (!port) {
        port = 3080;
    }
    NSMutableDictionary *paras = [NSMutableDictionary dictionaryWithObjectsAndKeys:_openUDID, @"client",
                                  @"false", @"background",
                                  kPlatfromNumber, @"type",
                                  [Utility version], @"version",
                                  nil];
    [_socketIO connectToHost:ip onPort:port withParams:paras withNamespace:@"/nba_v1"];
    DLog(@"socket connectToHost:%@ onPort:%ld", ip, (long)port);
}


- (void)reRequestRedirector {
	_tryFetchCount = 0;
    
    NSString *urlStr = [NSString stringWithFormat:@"%@redirector/", _host];
    
    ASIHTTPRequest *request = [ ASIHTTPRequest requestWithURL :[NSURL URLWithString:urlStr]];
    
    [request setDelegate:self];
    [request startAsynchronous];

}

- ( void )requestFinished:( ASIHTTPRequest *)request
{
    NSArray *data = [PUtility convertJSONToArray:[request responseString]];
    DLog(@"ipAndPort 返回: %@", data);
    if ([data count] > 0) {
        self.ipAndPort = [data objectAtIndex:0];
        [self connectSocketWithIpAndPort:self.ipAndPort];
    }
}

- ( void )requestFailed:( ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog ( @"requestFailed:%@" ,error. userInfo );
}

#pragma mark - leave

- (void)leaveRoom {
	NSString *roomToLeave = nil;
	switch (_socketRoom) {
		case CHAT:
			roomToLeave = @"CHAT_CASINO";
			break;

		default:
			break;
	}
	if (_socketRoom != NBA_NOROOM) {
		NSDictionary *joinData = [NSDictionary dictionaryWithObjectsAndKeys:roomToLeave, @"room", nil];
		[_socketIO sendEvent:@"leave" withData:joinData];
		_socketRoom = NBA_NOROOM;
		DLog(@"leave room  :  %@", roomToLeave);
	}
}

#pragma mark - join

/**
 *  热线
 *
 *  @param type
 *  @param gid
 *  @param pid
 *  @param direc
 *  @param roomid
 *  @param liveType 房间直播类型 1文字2视频（join时会给出该字段，用于渲染文字或视频的切换）
 */
- (void)joinRoomChatWithType:(NSString *)type
                         gid:(NSString *)gid
                         pid:(NSString *)pid
                       direc:(NSString *)direc
                  withRoomId:(NSString *)roomid {
	NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
	                             @"CHAT_CASINO", @"room",
	                             type, @"type",
	                             gid, @"gid",
	                             roomid, @"roomid",
	                             nil];

	if (pid != nil) {
		[data setObject:pid forKey:@"pid"];
	}

	if (direc != nil) {
		[data setObject:direc forKey:@"direc"];
	}
	_socket_emit_data = data;

	if (_socketIO.isConnected) {
		_roomForJoin = NBA_NOROOM;

		_socketRoom = CHAT;
		[_socketIO sendEvent:@"join" withData:_socket_emit_data];
		DLog(@"joinRoomChat : %@", [_socket_emit_data description]);
	}else {
		_roomForJoin = CHAT;
		[self connectSocket];
	}
}

/*
- (void)rejoinIfLostConnect {
    NSString* _enName = [_socket_emit_data objectForKey:@"type"];
    NSString* _gid = [_socket_emit_data objectForKey:@"gid"];
    NSString* _latestPid = [_socket_emit_data objectForKey:@"pid"];
    NSString* _roomId = [_socket_emit_data objectForKey:@"roomid"];
    
    [self joinRoomChatWithType:_enName gid:_gid pid:_latestPid direc:@"next" withRoomId:_roomId];
}*/

#pragma mark - SocketIODelegate

- (void)socketIODidConnect:(SocketIO *)socket {
	DLog(@"socketIODidConnect");
	switch (_roomForJoin) {
		case NBA_NOROOM:
		case CHAT:
			[_socketIO sendEvent:@"join" withData:_socket_emit_data];
			DLog(@"socketIODidConnect : emitData = %@", [_socket_emit_data description]);
			break;

		default:
			break;
	}
	_socketRoom = _roomForJoin;
	_tryFetchCount = 0;
}

- (void)socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error {
	DLog(@"socketIODidDisconnect");
	if (!isBackground) {
		_tryFetchCount = 0;
        if (_m_delegate_chat_casino && [_m_delegate_chat_casino respondsToSelector:@selector(rejoinIfLostConnect)]){
            [_m_delegate_chat_casino rejoinIfLostConnect];
        }
	}
}

//old versin delegate,keep it
- (void)socketIOHandshakeFailed:(SocketIO *)socket {
	DLog(@"socketIOHandshakeFailed");
	[self reconnectAfterSomeTime];
}

//old version delegate,keep it
- (void)socketIO:(SocketIO *)socket failedToConnectWithError:(NSError *)error {
	DLog(@"failedToConnectWithError : %@", [error localizedDescription]);
	[self reconnectAfterSomeTime];
}

- (void)socketIO:(SocketIO *)socket onError:(NSError *)error {
	if (error.code == SocketIOHandshakeFailed) {
		DLog(@"socketIOHandshakeFailed");
		[self reconnectAfterSomeTime];
	}else if (error.code == SocketIOServerRespondedWithDisconnect) {
		DLog(@"SocketIOServerRespondedWithDisconnect");
		[self reconnectAfterSomeTime];
	}
    
    if (_m_delegate_chat_casino && [_m_delegate_chat_casino respondsToSelector:@selector(socketConnectFailed)]){
        [_m_delegate_chat_casino socketConnectFailed];
    }
}

- (void)socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet {
	//NSDictionary *jsonData = [packet.data JSONValue];
	NSError *errorJson;
	NSDictionary *data = [NSJSONSerialization JSONObjectWithData:[packet.data dataUsingEncoding:NSUTF8StringEncoding]
	                                                     options:NSJSONReadingMutableContainers
	                                                       error:&errorJson];
	if (!errorJson && data) {
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[self handleSocketData:data];
		});
	}
}


#pragma mark - deal with socket data
//deal with data
- (void)handleSocketData:(NSDictionary *)jsonData {
	NSString *name = [jsonData stringValueForKey:@"name"];
	id args = [jsonData objectForKey:@"args"];
	//NSLog(@"json data:%@",jsonData);
	if ([name isEqualToString:@"wall"]) {
		if ([args isKindOfClass:[NSArray class]]) {
			if ([args count] > 0) {
				id item = [args objectAtIndex:0];
				NSString *room = [item stringValueForKey:@"room"];
				DLog(@"receive socket data:   room = %@", room);
                if ([room isEqualToString:@"CHAT"] || [room isEqualToString:@"CHAT_CASINO"]) {
                    if (_m_delegate_chat_casino && [_m_delegate_chat_casino respondsToSelector:@selector(handleSocketNotification:)]) {
                        [_m_delegate_chat_casino handleSocketNotification:item];
                    }
				}else if ([room isEqualToString:@"USER_NOTIFY"]) {
					[[NSNotificationCenter defaultCenter] postNotificationName:kPushDataUserNotify object:item];//this one use notification
				}
			}
		}
	}
}


- (void)setDelegate:(id)sender type:(SOCKET_DELEGATE_TYPE)type {
    [self clearAllDelegate];
    if (!sender) {
        return;
    }
    switch (type) {
        case DelegateType_chat_casino:
            _m_delegate_chat_casino = sender;
            break;
        default:
            break;
    }
}

- (void)clearAllDelegate {
    if (_m_delegate_chat_casino) {
        _m_delegate_chat_casino = nil;
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
    isBackground = NO;
}

- (void)applicationWillResignActive
{

}

- (void)applicationDidEnterBackground
{
    isBackground = YES;
}

- (void)applicationWillTerminate
{
    isBackground = YES;
}


@end
