//
//  GlobalWebSocketManager.h
//  games
//
//  Created by hupu on 14/11/14.
//
//


#import "SocketIO.h"
#import "SocketIOPacket.h"


typedef NS_ENUM (NSInteger,ROOM){
  NBA_NOROOM,
  CHAT,
};


typedef NS_ENUM (NSInteger,SOCKET_DELEGATE_TYPE){
    DelegateType_chat_casino,
};



@protocol GlobalWebSocketManagerDelegate <NSObject>

@optional
-(void)socketConnectFailed;
-(void)handleSocketNotification:(NSDictionary *)jsonData;

-(void)rejoinIfLostConnect;

@end



@interface GlobalWebSocketManager : NSObject<SocketIODelegate>
@property (assign, nonatomic ) ROOM                           socketRoom;
@property (assign, nonatomic ) ROOM                           roomForJoin;
@property (nonatomic,strong  ) SocketIO                       *socketIO;
@property (nonatomic, assign ) NSInteger                      tryFetchCount;

@property (nonatomic, strong ) NSString                       *ipAndPort;
@property (nonatomic, strong ) NSString                       *openUDID;
@property (nonatomic, strong ) NSString                       *host;

@property (nonatomic, weak)id<GlobalWebSocketManagerDelegate> m_delegate_chat_casino;

/**
 * gets singleton object.
 * @return singleton
 */
+ (GlobalWebSocketManager*)sharedInstance;

- (void)setDelegate:(id)sender type:(SOCKET_DELEGATE_TYPE)type;

- (void)reRequestRedirector;

#pragma mark - 加入/离开Room
- (void)joinRoomChatWithType:(NSString*)type gid:(NSString*)gid pid:(NSString*)pid direc:(NSString*)direc withRoomId:(NSString *)roomid;
- (void)leaveRoom;

@end
