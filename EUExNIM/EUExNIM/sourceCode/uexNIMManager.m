//
//  uexNIMManager.m
//  EUExNIM
//
//  Created by 黄锦 on 16/1/8.
//  Copyright © 2016年 AppCan. All rights reserved.
//

#import "uexNIMManager.h"

@interface uexNIMManager()

@end

@implementation uexNIMManager

+(instancetype)sharedInstance{
    static dispatch_once_t pred = 0;
    __strong static uexNIMManager *sharedObject = nil;
    dispatch_once(&pred, ^{
        sharedObject = [[self alloc] init];
        
        
    });
    return sharedObject;
}
-(instancetype)init{
    self=[super init];
    if(self){
        self.callBackDispatchQueue=dispatch_queue_create("gcd.uexNIMCallBackDispatchQueue",NULL);
    }
    return self;
}
#pragma mark -registerApp
-(void) registerApp:(NSString *)appKey apnsCertName:(NSString *)apnsCertName Function:(ACJSFunctionRef *)func{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if([appKey length]){
        if(!_SDK){
            _SDK=[NIMSDK sharedSDK];
            [_SDK registerWithAppID:appKey
                            cerName:apnsCertName];
            [self addDelegate];
            [result setValue:[NSNumber numberWithBool:YES] forKey:@"reslut"];
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0))];
        }
        else{
            [result setValue:[NSNumber numberWithBool:NO] forKey:@"reslut"];
            [result setValue:@(0) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1))];
        }
    }
    else{
        [result setValue:[NSNumber numberWithBool:NO] forKey:@"reslut"];
        [result setValue:@(1) forKey:@"error"];
        [func executeWithArguments:ACArgsPack(@(1))];
    }
    
    [self callBackJsonWithFunction:@"cbRegisterApp" parameter:result];
}
-(void)addDelegate{
    [self removeDelegate];
    
    [_SDK.loginManager addDelegate:self];
    [_SDK.chatManager addDelegate:self];
    [_SDK.conversationManager addDelegate:self];
    [_SDK.mediaManager addDelegate:self];
    [_SDK.teamManager addDelegate:self];
    [_SDK.userManager addDelegate:self];
    [_SDK.systemNotificationManager addDelegate:self];
    [_SDK.apnsManager addDelegate:self];
    [_SDK.netCallManager addDelegate:self];
    [_SDK.chatroomManager addDelegate:self];
    //[_SDK.rtsManager addDelegate:self];
    
}
-(void)removeDelegate{
    [_SDK.loginManager removeDelegate:self];
    [_SDK.chatManager removeDelegate:self];
    [_SDK.conversationManager removeDelegate:self];
    [_SDK.mediaManager removeDelegate:self];
    [_SDK.teamManager removeDelegate:self];
    [_SDK.userManager removeDelegate:self];
    [_SDK.systemNotificationManager removeDelegate:self];
    [_SDK.apnsManager removeDelegate:self];
    [_SDK.netCallManager removeDelegate:self];
    [_SDK.chatroomManager removeDelegate:self];
    //[_SDK.rtsManager removeDelegate:self];
    
}

- (void)onLogin:(NIMLoginStep)step{
    int stepNum = 0;
    if(step==NIMLoginStepLinking){
        stepNum=1;
    }
    if(step==NIMLoginStepLinkOK){
        stepNum=2;
    }
    if(step==NIMLoginStepLinkFailed){
        stepNum=3;
    }
    if(step==NIMLoginStepLogining){
        stepNum=4;
    }
    if(step==NIMLoginStepLoginOK){
        stepNum=5;
    }
    if(step==NIMLoginStepLoginFailed){
        stepNum=6;
    }
    if(step==NIMLoginStepSyncing){
        stepNum=7;
    }
    if(step==NIMLoginStepSyncOK){
        stepNum=8;
    }
    if(step==NIMLoginStepNetChanged){
        stepNum=9;
    }
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(stepNum) forKey:@"step"];
    [self callBackJsonWithFunction:@"onLogin" parameter:result];
}
-(void)onKick:(NIMKickReason)code clientType:(NIMLoginClientType)clientType{
    int resultCode = 0;
    if(code==NIMKickReasonByClient){
        resultCode=1;
    }
    if(code==NIMKickReasonByServer){
        resultCode=2;
    }
    if(code==NIMKickReasonByClientManually){
        resultCode=3;
    }
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(resultCode) forKey:@"code"];
    [self callBackJsonWithFunction:@"onKick" parameter:result];
}
- (void)onAutoLoginFailed:(NSError *)error{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(error.code) forKey:@"error"];
    [self callBackJsonWithFunction:@"onAutoLoginFailed" parameter:result];
}
- (void)onMultiLoginClientsChanged{
    NSArray *clients=[[self.SDK loginManager] currentLoginClients];
    NSMutableArray *result=[NSMutableArray array];
    for(NIMLoginClient *client in clients){
        NSMutableDictionary *clientDic=[NSMutableDictionary dictionary];
        [clientDic setValue:@(client.type) forKey:@"type"];
        [clientDic setValue:[NSString stringWithFormat:@"%f",client.timestamp] forKey:@"timestamp"];
        [clientDic setValue:client.os forKey:@"os"];
        [result addObject:clientDic];
    }
    [self callBackJsonWithFunction:@"onMultiLoginClientsChanged" parameter:@{@"clients":result}];
}

#pragma mark -3.基础消息功能
- (void)willSendMessage:(NIMMessage *)message{
    NSMutableDictionary *result=[self analyzeWithNIMMessage:message];
    
    [self callBackJsonWithFunction:@"willSendMessage" parameter:result];
}
- (void)sendMessage:(NIMMessage *)message progress:(CGFloat)progress{
    NSMutableDictionary *result=[self analyzeWithNIMMessage:message];
    [result setValue:@(progress) forKey:@"progress"];
    
    [self callBackJsonWithFunction:@"onSendMessageWithProgress" parameter:result];
}
- (void)sendMessage:(NIMMessage *)message didCompleteWithError:(NSError *)error{
    NSMutableDictionary *result=[self analyzeWithNIMMessage:message];
    
    if(error){
        [result setValue:@(error.code) forKey:@"error"];
        self.message=message;
    }
    else{
        [result setValue:@"" forKey:@"error"];
    }
    
    [self callBackJsonWithFunction:@"cbDidSendMessage" parameter:result];
    [self callBackJsonWithFunction:@"onMessageSend" parameter:result];
}
- (void)onRecvMessages:(NSArray *)messages{
    NSMutableArray *results=[NSMutableArray array];
    for (NIMMessage *message in messages) {
        NSDictionary *result=[self analyzeWithNIMMessage:message];
        [results addObject:result];
    }
    [self callBackJsonWithFunction:@"onRecvMessages" parameter:results];
}
- (void)fetchMessageAttachment:(NIMMessage *)message progress:(CGFloat)progress{
    NSMutableDictionary *result=[self analyzeWithNIMMessage:message];
    [result setValue:@(progress) forKey:@"progress"];
    
    [self callBackJsonWithFunction:@"onFetchMessageAttachment" parameter:result];
}

- (void)fetchMessageAttachment:(NIMMessage *)message didCompleteWithError:(NSError *)error{
    NSMutableDictionary *result=[self analyzeWithNIMMessage:message];
    if(error){
        [result setValue:@(error.code) forKey:@"error"];
    }
    else{
        [result setValue:@"" forKey:@"error"];
    }
    
    [self callBackJsonWithFunction:@"cbFetchMessageAttachment" parameter:result];
}
- (void)didAddRecentSession:(NIMRecentSession *)recentSession totalUnreadCount:(NSInteger)totalUnreadCount{
    NSMutableDictionary *sessionDic=[self analyzeWithNIMRecentSession:recentSession];
    [sessionDic setValue:@(totalUnreadCount) forKey:@"totalUnreadCount"];
    [self callBackJsonWithFunction:@"onAddRecentSession" parameter:sessionDic];
}
- (void)didUpdateRecentSession:(NIMRecentSession *)recentSession totalUnreadCount:(NSInteger)totalUnreadCount{
    NSMutableDictionary *sessionDic=[self analyzeWithNIMRecentSession:recentSession];
    [sessionDic setValue:@(totalUnreadCount) forKey:@"totalUnreadCount"];
    [self callBackJsonWithFunction:@"onUpdateRecentSession" parameter:sessionDic];
}
- (void)didRemoveRecentSession:(NIMRecentSession *)recentSession totalUnreadCount:(NSInteger)totalUnreadCount{
    NSMutableDictionary *sessionDic=[self analyzeWithNIMRecentSession:recentSession];
    [sessionDic setValue:@(totalUnreadCount) forKey:@"totalUnreadCount"];
    [self callBackJsonWithFunction:@"onRemoveRecentSession" parameter:sessionDic];
}
- (void)allMessagesDeleted{
    [self callBackJsonWithFunction:@"cbDeleteAllMessages" parameter:nil];
}

#pragma mark -5.语音录制及回放
-(void)playAudio:(NSString *)filePath{

//    [[self.SDK mediaManager] playAudio:filePath withDelegate:self];
    [[self.SDK mediaManager] play:filePath];
}
- (void)playAudio:(NSString *)filePath didBeganWithError:(NSError *)error{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if(error){
        [result setValue:@(error.code) forKey:@"error"];
    }
    else{
        [result setValue:@"" forKey:@"error"];
    }
    [result setValue:filePath forKey:@"filePath"];
    [self callBackJsonWithFunction:@"cbBeganPlayAudio" parameter:result];
    [self callBackJsonWithFunction:@"onBeganPlayAudio" parameter:result];
    
}
- (void)playAudio:(NSString *)filePath didCompletedWithError:(NSError *)error{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if(error){
        [result setValue:@(error.code) forKey:@"error"];
    }
    else{
        [result setValue:@"" forKey:@"error"];
    }
    [result setValue:filePath forKey:@"filePath"];
    [self callBackJsonWithFunction:@"cbCompletedPlayAudio" parameter:result];
    [self callBackJsonWithFunction:@"onCompletedPlayAudio" parameter:result];
}
- (void)recordAudio:(NSString *)filePath didBeganWithError:(NSError *)error{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if(error){
        [result setValue:@(error.code) forKey:@"error"];
    }
    else{
        [result setValue:@"" forKey:@"error"];
    }
    [result setValue:filePath forKey:@"filePath"];
    [self callBackJsonWithFunction:@"cbBeganRecordAudio" parameter:result];
}
- (void)recordAudio:(NSString *)filePath didCompletedWithError:(NSError *)error{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if(error){
        [result setValue:@(error.code) forKey:@"error"];
    }
    else{
        [result setValue:@"" forKey:@"error"];
    }
    [result setValue:filePath forKey:@"filePath"];
    [self callBackJsonWithFunction:@"cbCompletedRecordAudio" parameter:result];
}
- (void)recordAudioProgress:(NSTimeInterval)currentTime{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(currentTime) forKey:@"currentTime"];
    [self callBackJsonWithFunction:@"onRecordAudioProgress" parameter:result];
}
//取消录音回调
- (void)recordAudioDidCancelled{
    [self callBackJsonWithFunction:@"cbCecordAudioDidCancelled" parameter:nil];
}
//来电打断监听
-(void)onPlayAudioInterruptionBegin{
    [self callBackJsonWithFunction:@"onPlayAudioInterruptionBegin" parameter:nil];
}
//来电打断监听
-(void)onRecordAudioInterruptionBegin{
    [self callBackJsonWithFunction:@"onRecordAudioInterruptionBegin" parameter:nil];
}
//通话结束监听
-(void)onPlayAudioInterruptionEnd{
    [self callBackJsonWithFunction:@"onPlayAudioInterruptionEnd" parameter:nil];
}
//通话结束监听
-(void)onRecordAudioInterruptionEnd{
    [self callBackJsonWithFunction:@"onRecordAudioInterruptionEnd" parameter:nil];
}
#pragma mark -6.群组功能
- (void)onTeamAdded:(NIMTeam *)team{
    NSMutableDictionary *result=[self analyzeWithNIMTeam:team];
    [self callBackJsonWithFunction:@"onTeamAdded" parameter:@{@"team":result}];
}
- (void)onTeamUpdated:(NIMTeam *)team{
    NSMutableDictionary *result=[self analyzeWithNIMTeam:team];
    [self callBackJsonWithFunction:@"onTeamUpdated" parameter:@{@"team":result}];
}
- (void)onTeamRemoved:(NIMTeam *)team{
    NSMutableDictionary *result=[self analyzeWithNIMTeam:team];
    [self callBackJsonWithFunction:@"onTeamRemoved" parameter:@{@"team":result}];
}
#pragma mark -7.系统通知
-(void)onReceiveSystemNotification:(NIMSystemNotification *)notification{
    NSMutableDictionary *result=[self analyzeWithSystemNotification:notification];
    [self callBackJsonWithFunction:@"onReceiveSystemNotification" parameter:@{@"notification":result}];
}
- (void)onReceiveCustomSystemNotification:(NIMCustomSystemNotification *)notification{
    NSMutableDictionary *result=[self analyzeWithCustomNotification:notification];
    [self callBackJsonWithFunction:@"onReceiveCustomSystemNotification" parameter:@{@"notification":result}];
}
#pragma mark -9.用户资料托管
- (void)onUserInfoChanged:(NIMUser *)user{
    NSMutableDictionary *result=[self analyzeWithNIMUser:user];
    [self callBackJsonWithFunction:@"onUserInfoChanged" parameter:@{@"user":result}];
}
#pragma mark -10.用户关系托管
- (void)onFriendChanged:(NIMUser *)user{
    NSMutableDictionary *result=[self analyzeWithNIMUser:user];
    [self callBackJsonWithFunction:@"onFriendChanged" parameter:@{@"user":result}];
}
- (void)onBlackListChanged{
    [self callBackJsonWithFunction:@"onBlackListChanged" parameter:nil];
}
#pragma mark -11.音视频通话
//被叫收到通话请求
- (void)onReceive:(UInt64)callID from:(NSString *)caller type:(NIMNetCallType)type message:(NSString *)extendMessage{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(type) forKey:@"type"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    [result setValue:caller forKey:@"userId"];
    
    [self callBackJsonWithFunction:@"onReceive" parameter:result];
}
//主叫收到被叫响应
- (void)onResponse:(UInt64)callID from:(NSString *)callee accepted:(BOOL)accepted{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(accepted) forKey:@"accepted"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    [result setValue:callee forKey:@"userId"];
    
    [self callBackJsonWithFunction:@"onResponse" parameter:result];
}
//呼入的通话已经被该帐号其他端处理
- (void)onResponsedByOther:(UInt64)callID accepted:(BOOL)accepted{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(accepted) forKey:@"accepted"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    
    [self callBackJsonWithFunction:@"onResponsedByOther" parameter:result];
}
//连接建立结果回调
- (void)onCall:(UInt64)callID status:(NIMNetCallStatus)status{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(status) forKey:@"status"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    
    [self callBackJsonWithFunction:@"onCall" parameter:result];
}
//收到通话控制信息回调
- (void)onControl:(UInt64)callID from:(NSString *)user type:(NIMNetCallControlType)control{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(control) forKey:@"type"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    [result setValue:user forKey:@"userId"];
    
    [self callBackJsonWithFunction:@"onControl" parameter:result];
}
//收到对方结束通话回调
- (void)onHangup:(UInt64)callID by:(NSString *)user{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    [result setValue:user forKey:@"userId"];
    
    [self callBackJsonWithFunction:@"onHangup" parameter:result];
}
//当前通话网络状况回调
- (void)onCall:(UInt64)callID netStatus:(NIMNetCallNetStatus)status{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(status) forKey:@"status"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    
    [self callBackJsonWithFunction:@"onCallNetStatus" parameter:result];
}
//本地摄像头预览就绪回调
- (void)onLocalPreviewReady:(CALayer *)layer{
    if (self.localVideoLayer) {
        [self.localVideoLayer removeFromSuperlayer];
    }
    self.localVideoLayer = layer;
    layer.frame = self.localView.bounds;
    [self.localView.layer addSublayer:layer];
}
//远程视频YUV数据就绪
//- (void)onRemoteYUVReady:(NSData *)yuvData width:(NSUInteger)width height:(NSUInteger)height{
//    if (([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) && !self.oppositeCloseVideo) {
//        
//        [self.remoteGLView render:yuvData width:width height:height];
//    }
//}
//远程视频画面就绪回调
- (void)onRemoteImageReady:(CGImageRef)image{
    self.remoteView.contentMode = UIViewContentModeScaleToFill;
    self.remoteView.image = [UIImage imageWithCGImage:image];
}
- (void)onLocalRecordStarted:(UInt64)callID fileURL:(NSURL *)fileURL{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:[NSString stringWithFormat:@"%@",fileURL] forKey:@"filePath"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    
    [self callBackJsonWithFunction:@"onLocalRecordStarted" parameter:result];
}
- (void)onLocalRecordError:(NSError *)error callID:(UInt64)callID{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(error.code) forKey:@"error"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    
    [self callBackJsonWithFunction:@"onLocalRecordError" parameter:result];
}
- (void)onLocalRecordStopped:(UInt64)callID fileURL:(NSURL *)fileURL{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:[NSString stringWithFormat:@"%@",fileURL] forKey:@"filePath"];
    [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
    
    [self callBackJsonWithFunction:@"onLocalRecordStopped" parameter:result];
}

#pragma mark -12.实时会话（白板）
//- (void)onRTSRequest:(NSString *)sessionID from:(NSString *)caller services:(NSUInteger)types  message:(NSString *)extendMessage{
//    NSMutableDictionary *result=[NSMutableDictionary dictionary];
//    [result setValue:sessionID forKey:@"sessionId"];
//    [result setValue:caller forKey:@"userId"];
//    [result setValue:extendMessage forKey:@"extendMessage"];
//    
//    [self callBackJsonWithFunction:@"onRTSResponse" parameter:result];
//}
//- (void)onRTSResponsedByOther:(NSString *)sessionID accepted:(BOOL)accepted{
//    NSMutableDictionary *result=[NSMutableDictionary dictionary];
//    [result setValue:sessionID forKey:@"sessionId"];
//    
//    [self callBackJsonWithFunction:@"onRTSResponsedByOther" parameter:result];
//}


#pragma mark -9.聊天室

- (void)chatroom:(NSString *)roomId connectionStateChanged:(NIMChatroomConnectionState)state{
    [self callBackJsonWithFunction:@"onChatRoomStatusChanged" parameter:@{@"roomId":roomId,@"status":@(state)}];
}
- (void)chatroom:(NSString *)roomId autoLoginFailed:(NSError *)error{

}
- (void)chatroom:(NSString *)roomId beKicked:(NIMChatroomKickReason)reason{
     [self callBackJsonWithFunction:@"onChatRoomKickOutEvent" parameter:@{@"roomId":roomId,@"code":@(reason)}];
}

#pragma mark -analyze
-(NSMutableDictionary*)analyzeWithCustomNotification:(NIMCustomSystemNotification *)notification{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(notification.receiverType)?:@"" forKey:@"receiverType"];
    [result setValue:@(notification.timestamp)?:@"" forKey:@"timestamp"];
    [result setValue:notification.sender?:@"" forKey:@"sender"];
    [result setValue:notification.receiver?:@"" forKey:@"receiver"];
    [result setValue:notification.content?:@"" forKey:@"content"];
    [result setValue:notification.apnsContent?:@"" forKey:@"apnsContent"];
    
    return  result;
}
-(NSMutableDictionary*)analyzeWithSystemNotification:(NIMSystemNotification *)notification{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(notification.type)?:@"" forKey:@"type"];
    [result setValue:@(notification.timestamp)?:@"" forKey:@"timestamp"];
    [result setValue:notification.sourceID?:@"" forKey:@"sourceID"];
    [result setValue:notification.targetID?:@"" forKey:@"targetID"];
    [result setValue:notification.postscript?:@"" forKey:@"postscript"];
    [result setValue:@(notification.handleStatus)?:@"" forKey:@"handleStatus"];
    [result setValue:@(notification.read)?:@"" forKey:@"read"];
    
    return  result;
}
-(NSMutableDictionary*)analyzeWithNIMMessage:(NIMMessage *)message{
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:message.from?:@"" forKey:@"from"];
    [result setValue:message.messageId?:@"" forKey:@"messageId"];
    [result setValue:message.text?:@"" forKey:@"text"];
    [result setValue:@(message.messageType)?:@"" forKey:@"messageType"];
    [result setValue:message.senderName?:@"" forKey:@"senderName"];
    [result setValue:@(message.timestamp)?:@"" forKey:@"timestamp"];
    [result setValue:message.session.sessionId?:@"" forKey:@"sessionId"];
    [result setValue:@(message.session.sessionType)?:@"" forKey:@"sessionType"];
    [result setValue:@(message.isPlayed)?:@"" forKey:@"isPlayed"];
    [result setValue:@(message.isDeleted)?:@"" forKey:@"isDeleted"];
    [result setValue:@(message.isOutgoingMsg)?:@"" forKey:@"isOutgoingMsg"];
    [result setValue:@(message.isReceivedMsg)?:@"" forKey:@"isReceivedMsg"];
    [result setValue:message.remoteExt?:@"" forKey:@"ext"];
    
    NIMNotificationContent *notificationContent;
    NSMutableArray *targets=[NSMutableArray array];
    switch (message.messageType) {
        case NIMMessageTypeImage:
            [result setValue:@([(NIMImageObject *)message.messageObject fileLength])?:@"" forKey:@"fileLength"];
            [result setValue:[(NIMImageObject *)message.messageObject path]?:@"" forKey:@"path"];
            [result setValue:[(NIMImageObject *)message.messageObject thumbPath]?:@"" forKey:@"thumbPath"];
            [result setValue:[(NIMImageObject *)message.messageObject thumbUrl]?:@"" forKey:@"thumbUrl"];
            [result setValue:[(NIMImageObject *)message.messageObject url]?:@"" forKey:@"url"];
            [result setValue:[(NIMImageObject *)message.messageObject displayName]?:@"" forKey:@"displayName"];
            
            break;
        case NIMMessageTypeAudio:
            [result setValue:@([(NIMAudioObject *)message.messageObject duration])?:@"" forKey:@"duration"];
            [result setValue:[(NIMAudioObject *)message.messageObject path]?:@"" forKey:@"path"];
            [result setValue:[(NIMAudioObject *)message.messageObject url]?:@"" forKey:@"url"];
            
            break;
        case NIMMessageTypeVideo:
            [result setValue:@([(NIMVideoObject *)message.messageObject fileLength])?:@"" forKey:@"fileLength"];
            [result setValue:[(NIMVideoObject *)message.messageObject path]?:@"" forKey:@"path"];
            [result setValue:[(NIMVideoObject *)message.messageObject coverUrl]?:@"" forKey:@"coverUrl"];
            [result setValue:[(NIMVideoObject *)message.messageObject coverPath]?:@"" forKey:@"coverPath"];
            [result setValue:[(NIMVideoObject *)message.messageObject url]?:@"" forKey:@"url"];
            [result setValue:[(NIMVideoObject *)message.messageObject displayName]?:@"" forKey:@"displayName"];
            [result setValue:@([(NIMVideoObject *)message.messageObject duration])?:@"" forKey:@"duration"];
            
            break;
        case NIMMessageTypeFile:
            [result setValue:@([(NIMFileObject *)message.messageObject fileLength])?:@"" forKey:@"fileLength"];
            [result setValue:[(NIMFileObject *)message.messageObject path]?:@"" forKey:@"path"];
            [result setValue:[(NIMFileObject *)message.messageObject url]?:@"" forKey:@"url"];
            [result setValue:[(NIMFileObject *)message.messageObject displayName]?:@"" forKey:@"displayName"];
            
            break;
        case NIMMessageTypeLocation:
            [result setValue:@([(NIMLocationObject *)message.messageObject latitude])?:@"" forKey:@"latitude"];
            [result setValue:@([(NIMLocationObject *)message.messageObject longitude])?:@"" forKey:@"longitude"];
            [result setValue:[(NIMLocationObject *)message.messageObject title]?:@"" forKey:@"title"];
            
            break;
        case NIMMessageTypeNotification:
            
            [result setValue:@([(NIMNotificationObject *)message.messageObject notificationType])?:@"" forKey:@"notificationType"];
            //[result setValue:[(NIMNotificationObject *)message.messageObject content]?:@"" forKey:@"content"];
            notificationContent=[(NIMNotificationObject *)message.messageObject content];
            switch ([(NIMNotificationObject *)message.messageObject notificationType]) {
                case NIMNotificationTypeTeam:
                    
                    [result setValue:@([(NIMTeamNotificationContent *)notificationContent operationType]) forKey:@"eventType"];
                    [result setValue:[(NIMTeamNotificationContent *)notificationContent sourceID]forKey:@"operator"];
                    [result setValue:[(NIMTeamNotificationContent *)notificationContent targetIDs]?:@"" forKey:@"targets"];
                    
                    break;
                case NIMNotificationTypeNetCall:
                    
                    [result setValue:@([(NIMNetCallNotificationContent *)notificationContent callType]) forKey:@"callType"];
                    [result setValue:@([(NIMNetCallNotificationContent *)notificationContent eventType]) forKey:@"eventType"];
                    [result setValue:@([(NIMNetCallNotificationContent *)notificationContent callID]) forKey:@"callID"];
                    [result setValue:@([(NIMNetCallNotificationContent *)notificationContent duration]) forKey:@"callDuration"];
                    
                    break;
                case NIMNotificationTypeChatroom:
                    
                    [result setValue:@([(NIMChatroomNotificationContent *)notificationContent eventType])?:@"" forKey:@"eventType"];
                    [result setValue:[(NIMChatroomNotificationContent *)notificationContent source].userId?:@"" forKey:@"operator"];
//                    [result setValue:[(NIMChatroomNotificationContent *)notificationContent source].nick?:@"" forKey:@"operatorNick"];
//                    [result setValue:[(NIMChatroomNotificationContent *)notificationContent notifyExt]?[[(NIMChatroomNotificationContent *)notificationContent notifyExt] JSONValue]:@"" forKey:@"notifyExt"];
                    
                    if([(NIMChatroomNotificationContent *)notificationContent targets]){
                        for (NIMChatroomMember *member in [(NIMChatroomNotificationContent *)notificationContent targets]) {
                            [targets addObject:member.userId];
                        }
                    }
                    [result setValue:targets?:@"" forKey:@"targets"];
                    [result setValue:[(NIMChatroomNotificationContent *)notificationContent notifyExt]?[[(NIMChatroomNotificationContent *)notificationContent notifyExt] ac_JSONValue]:@"" forKey:@"notifyExtension"];
                    
                    break;
                    
                default:
                    break;
            }
            
            
            break;
            
        default:
            break;
    }
    return result;
}
-(NSMutableDictionary*)analyzeWithNIMRecentSession:(NIMRecentSession *)recentSession{
    NSMutableDictionary *sessionDic=[NSMutableDictionary dictionary];
    [sessionDic setValue:[self analyzeWithNIMMessage:recentSession.lastMessage ]?:@"" forKey:@"lastMessage"];
    [sessionDic setValue:@(recentSession.unreadCount)?:@"" forKey:@"unreadCount"];
    [sessionDic setValue:recentSession.session.sessionId?:@"" forKey:@"sessionId"];
    [sessionDic setValue:@(recentSession.session.sessionType)?:@"" forKey:@"sessionType"];
    return sessionDic;
}
-(NSMutableDictionary*)analyzeWithNIMTeam:(NIMTeam *)team{
    NSMutableDictionary *sessionDic=[NSMutableDictionary dictionary];
    [sessionDic setValue:@(team.type)?:@"" forKey:@"type"];
    [sessionDic setValue:team.teamName?:@"" forKey:@"teamName"];
    [sessionDic setValue:team.teamId?:@"" forKey:@"teamId"];
    [sessionDic setValue:team.owner?:@"" forKey:@"owner"];
    [sessionDic setValue:team.intro?:@"" forKey:@"intro"];
    [sessionDic setValue:team.announcement?:@"" forKey:@"announcement"];
    [sessionDic setValue:@(team.memberNumber)?:@"" forKey:@"memberNumber"];
    [sessionDic setValue:@(team.level)?:@"" forKey:@"level"];
    [sessionDic setValue:@(team.createTime)?:@"" forKey:@"createTime"];
    [sessionDic setValue:@(team.joinMode)?:@"" forKey:@"joinMode"];
    [sessionDic setValue:@(team.notifyForNewMsg)?:@"" forKey:@"notifyForNewMsg"];
    [sessionDic setValue:team.serverCustomInfo?:@"" forKey:@"serverCustomInfo"];
    [sessionDic setValue:team.clientCustomInfo?:@"" forKey:@"clientCustomInfo"];
    
    return sessionDic;
}
-(NSMutableDictionary*)analyzeWithNIMTeamMember:(NIMTeamMember *)member{
    NSMutableDictionary *memberDic=[NSMutableDictionary dictionary];
    [memberDic setValue:member.nickname?:@"" forKey:@"nickname"];
    [memberDic setValue:member.teamId?:@"" forKey:@"teamId"];
    [memberDic setValue:member.userId?:@"" forKey:@"userId"];
    [memberDic setValue:member.invitor?:@"" forKey:@"invitor"];
    [memberDic setValue:@(member.type)?:@"" forKey:@"type"];
    
    return memberDic;
}
-(NSMutableDictionary*)analyzeWithNIMUser:(NIMUser *)user{
    NSMutableDictionary *resultDic=[NSMutableDictionary dictionary];
    [resultDic setValue:user.alias?:@"" forKey:@"alias"];
    [resultDic setValue:user.userId?:@"" forKey:@"userId"];
    [resultDic setValue:@(user.notifyForNewMsg)?:@"" forKey:@"notifyForNewMsg"];
    [resultDic setValue:@(user.isInMyBlackList)?:@"" forKey:@"isInMyBlackList"];
    [resultDic setValue:[self analyzeWithNIMUserInfo:user.userInfo]?:@"" forKey:@"userInfo"];
    
    return resultDic;
}
-(NSMutableDictionary*)analyzeWithNIMUserInfo:(NIMUserInfo *)user{
    NSMutableDictionary *resultDic=[NSMutableDictionary dictionary];
    [resultDic setValue:user.nickName?:@"" forKey:@"nickName"];
    [resultDic setValue:user.avatarUrl?:@"" forKey:@"avatarUrl"];
    [resultDic setValue:user.thumbAvatarUrl?:@"" forKey:@"thumbAvatarUrl"];
    [resultDic setValue:user.sign?:@"" forKey:@"sign"];
    [resultDic setValue:@(user.gender)?:@"" forKey:@"gender"];
    [resultDic setValue:user.email?:@"" forKey:@"email"];
    [resultDic setValue:user.birth?:@"" forKey:@"birth"];
    [resultDic setValue:user.mobile?:@"" forKey:@"mobile"];
    [resultDic setValue:user.ext?:@"" forKey:@"ext"];
    
    return resultDic;
}
-(NSMutableDictionary*)analyzeWithNIMChatroom:(NIMChatroom *)room{
    NSMutableDictionary *resultDic=[NSMutableDictionary dictionary];
    [resultDic setValue:room.roomId?:@"" forKey:@"roomId"];
    [resultDic setValue:room.name?:@"" forKey:@"name"];
    [resultDic setValue:room.announcement?:@"" forKey:@"announcement"];
    [resultDic setValue:room.creator?:@"" forKey:@"creator"];
    [resultDic setValue:@(room.onlineUserCount)?:@"" forKey:@"onlineUserCount"];
    [resultDic setValue:room.broadcastUrl?:@"" forKey:@"broadcastUrl"];
    [resultDic setValue:room.ext?[room.ext ac_JSONValue]:@"" forKey:@"extention"];
    
    return resultDic;
}
-(NSMutableDictionary*)analyzeWithNIMChatroomMember:(NIMChatroomMember *)member{
    NSMutableDictionary *resultDic=[NSMutableDictionary dictionary];
    [resultDic setValue:member.userId?:@"" forKey:@"userId"];
    [resultDic setValue:member.roomNickname?:@"" forKey:@"nick"];
    [resultDic setValue:member.roomAvatar?:@"" forKey:@"avatar"];
    [resultDic setValue:@(member.type)?:@"" forKey:@"memberType"];
    [resultDic setValue:@(member.isInBlackList)?:@"" forKey:@"isInBlackList"];
    [resultDic setValue:@(member.isMuted)?:@"" forKey:@"isMuted"];
    [resultDic setValue:@(member.isOnline)?:@"" forKey:@"isOnline"];
    [resultDic setValue:@(member.enterTimeInterval)?:@"" forKey:@"enterTime"];
    [resultDic setValue:member.roomExt?[member.roomExt ac_JSONValue]:@"" forKey:@"extention"];
    
    return resultDic;
}
#pragma mark - CallBack Method
const static NSString *kPluginName=@"uexNIM";
-(void)callBackJsonWithFunction:(NSString *)functionName parameter:(id)obj{
    
    NSString *paramStr=[obj ac_JSONFragment];
    NSString *jsonStr = [NSString stringWithFormat:@"if(%@.%@ != null){%@.%@('%@');}",kPluginName,functionName,kPluginName,functionName,paramStr];
    //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
    dispatch_async(self.callBackDispatchQueue, ^(void){
        [EUtility evaluatingJavaScriptInRootWnd:jsonStr];
    });
    
}
#pragma mark - Log
-(void) currentLogFilepath{
    NSString * currentLogFilepath=[self.SDK currentLogFilepath];
    NSString *str=[NSString stringWithContentsOfFile:currentLogFilepath encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"srt================================================================%@",str);
}
    
@end