//
//  EUExNIM.m
//  EUExNIM
//
//  Created by 黄锦 on 16/1/6.
//  Copyright © 2016年 AppCan. All rights reserved.
//
#import "uexNIMManager.h"
#import "EUExNIM.h"


@interface EUExNIM()<NIMLoginManagerDelegate>


@property (nonatomic,weak) uexNIMManager *uexNIMMgr;

@property(nonatomic,strong)ACJSFunctionRef *registerAPNSFunc;

@end


@implementation EUExNIM


-(id)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    if (self = [super initWithWebViewEngine:engine]) {
        self.uexNIMMgr=[uexNIMManager sharedInstance];
    }
    return self;
}


#pragma mark -1.registerApp
-(void) registerApp:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *appInfo,ACJSFunctionRef*func) = inArguments;
    [self.uexNIMMgr registerApp:[appInfo objectForKey:@"appKey"] apnsCertName:[appInfo objectForKey:@"apnsCertName"] Function:func];
}

#pragma mark -2.登录与登出
-(void) login:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *user, ACJSFunctionRef*func) = inArguments;
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    
    [[_uexNIMMgr.SDK loginManager] login:[user objectForKey:@"userId"] token:[[user objectForKey:@"password"] tokenByPassword] completion:^(NSError *error) {
        if(error){
            [result setValue:@"" forKey:@"userId"];
            [result setValue:[NSNumber numberWithBool:NO] forKey:@"result"];
            [result setValue:@(error.code) forKey:@"error"];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbLogin" parameter:result ];
            
            [func executeWithArguments:ACArgsPack(@(error.code),@"")];
            
        }
        else{
            [result setValue:@"" forKey:@"error"];
            NSString *userId=_uexNIMMgr.SDK.loginManager.currentAccount;
            [result setValue:userId forKey:@"userId"];
            [result setValue:[NSNumber numberWithBool:YES] forKey:@"result"];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbLogin" parameter:result ];
            
            [func executeWithArguments:ACArgsPack(@(0),userId)];
        }
    }];
    
}
-(void) autoLogin:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *user) = inArguments;
    [[_uexNIMMgr.SDK loginManager] autoLogin:[user objectForKey:@"userId"] token:[[user objectForKey:@"password"] tokenByPassword] ];
}
-(void)logout:(NSMutableArray *)inArguments{
    ACArgsUnpack(ACJSFunctionRef*func) = inArguments;
    [[self.uexNIMMgr.SDK loginManager] logout:^(NSError *error){
        if(error){
            [self.uexNIMMgr callBackJsonWithFunction:@"cbLogout" parameter:@{@"error":@(error.code)}];
            
            [func executeWithArguments:ACArgsPack(@(1),error.debugDescription)];
        }
        else{
            [self.uexNIMMgr callBackJsonWithFunction:@"cbLogout" parameter:@{@"error":@""}];
             [func executeWithArguments:ACArgsPack(@(0),@"")];
        }
    }];
    
}
-(void) registerUser:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *user) = inArguments;
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSString *urlString = [@"https://app.netease.im/api" stringByAppendingString:@"/createDemoUser"];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                            timeoutInterval:30];
    [request setHTTPMethod:@"Post"];
    
    [request addValue:@"application/x-www-form-urlencoded;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"nim_demo_ios" forHTTPHeaderField:@"User-Agent"];
    [request addValue:[self.uexNIMMgr.SDK appKey] forHTTPHeaderField:@"appkey"];
    
    NSString *postData = [NSString stringWithFormat:@"username=%@&password=%@&nickname=%@",[user objectForKey:@"userId"],[[user objectForKey:@"password"] tokenByPassword],[user objectForKey:@"nickname"]];
    [request setHTTPBody:[postData dataUsingEncoding:NSUTF8StringEncoding]];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSLog(@"location:%@", location);
        NSLog(@"thread:%@",[NSThread currentThread]);
        NSData *responseObject = [NSData dataWithContentsOfURL:location];
        NSString *dataStr= [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        id dataInfo=[dataStr ac_JSONValue];
        NSInteger statusCode = [[dataInfo objectForKey:@"res"] integerValue];
        if (statusCode == 200) {
            [result setValue:[NSNumber numberWithBool:YES] forKey:@"result"];
            [result setValue:@"" forKey:@"error"];
        }
        else
        {
            [result setValue:[NSNumber numberWithBool:NO] forKey:@"result"];
            [result setValue:[dataInfo objectForKey:@"errmsg"] forKey:@"error"];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbRegisterUser" parameter:result];
    }];
    
    [task resume];
}

#pragma mark -3.基础消息功能
-(void) sendText:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    NSString *content=[info objectForKey:@"content"];
    NIMMessage *message = [[NIMMessage alloc] init];
    message.text    = content;
    
    NSDictionary *remoteExt=nil;
    if([info objectForKey:@"ext"] &&![[info objectForKey:@"ext"] isEqual:@""]){
        remoteExt=[[info objectForKey:@"ext"] isKindOfClass:[NSDictionary class]]?[info objectForKey:@"ext"] : [[info objectForKey:@"ext"] ac_JSONValue];
    }
    message.remoteExt=remoteExt;
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    [self.uexNIMMgr.SDK.chatManager sendMessage:message toSession:session error:nil];
    
}
-(void) sendImage:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
     ACArgsUnpack(NSDictionary *info) = inArguments;
    if([info objectForKey:@"filePath"]==[NSNull null] || [[info objectForKey:@"filePath"] isEqual:@""]){
        return;
    }
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    
    UIImage  *image = [UIImage imageWithContentsOfFile:[self absPath:[info objectForKey:@"filePath"]]];
    NIMImageObject * imageObject = [[NIMImageObject alloc] initWithImage:image];
    imageObject.displayName=[info objectForKey:@"displayName"];
    if([info objectForKey:@"compressQuality"]){
        NIMImageOption *option       = [[NIMImageOption alloc] init];
        option.compressQuality=[[info objectForKey:@"compressQuality"] floatValue];
        imageObject.option=option;
    }
    
    NIMMessage *message          = [[NIMMessage alloc] init];
    message.messageObject        = imageObject;
    
    NSDictionary *remoteExt=nil;
    if([info objectForKey:@"ext"] &&![[info objectForKey:@"ext"] isEqual:@""]){
        remoteExt=[[info objectForKey:@"ext"] isKindOfClass:[NSDictionary class]]?[info objectForKey:@"ext"] : [[info objectForKey:@"ext"] ac_JSONValue];
    }
    message.remoteExt=remoteExt;
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    [self.uexNIMMgr.SDK.chatManager sendMessage:message toSession:session error:nil];
}
-(void) sendAudio:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    if([info objectForKey:@"filePath"]==[NSNull null] || [[info objectForKey:@"filePath"] isEqual:@""]){
        return;
    }
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    NSString *filePath=[info objectForKey:@"filePath"];
    
    NIMAudioObject *audioObject = [[NIMAudioObject alloc] initWithSourcePath:[self absPath:filePath]];
    
    NIMMessage *message        = [[NIMMessage alloc] init];
    message.messageObject      = audioObject;
    
    NSDictionary *remoteExt=nil;
    if([info objectForKey:@"ext"] &&![[info objectForKey:@"ext"] isEqual:@""]){
        remoteExt=[[info objectForKey:@"ext"] isKindOfClass:[NSDictionary class]]?[info objectForKey:@"ext"] : [[info objectForKey:@"ext"] ac_JSONValue];
    }
    message.remoteExt=remoteExt;
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    [self.uexNIMMgr.SDK.chatManager sendMessage:message toSession:session error:nil];
}
-(void) sendVideo:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    if([info objectForKey:@"filePath"]==[NSNull null] || [[info objectForKey:@"filePath"] isEqual:@""]){
        return;
    }
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    NSString *filePath=[info objectForKey:@"filePath"];
    
    NIMVideoObject *videoObject = [[NIMVideoObject alloc] initWithSourcePath:[self absPath:filePath]];
    videoObject.displayName=[info objectForKey:@"displayName"];
    
    NIMMessage *message         = [[NIMMessage alloc] init];
    message.messageObject       = videoObject;
    
    NSDictionary *remoteExt=nil;
    if([info objectForKey:@"ext"] &&![[info objectForKey:@"ext"] isEqual:@""]){
        remoteExt=[[info objectForKey:@"ext"] isKindOfClass:[NSDictionary class]]?[info objectForKey:@"ext"] : [[info objectForKey:@"ext"] ac_JSONValue];
    }
    message.remoteExt=remoteExt;
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    [self.uexNIMMgr.SDK.chatManager sendMessage:message toSession:session error:nil];
}
-(void) sendLocationMsg:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    double latitude=0;
    if([info objectForKey:@"latitude"]){
        latitude=[[info objectForKey:@"latitude"] doubleValue];
    }
    double longitude=0;
    if ([info objectForKey:@"longitude"]) {
        longitude=[[info objectForKey:@"longitude"] doubleValue];
    }
    NSString *title=[info objectForKey:@"title"];
    
    NIMLocationObject *locationObject = [[NIMLocationObject alloc] initWithLatitude:latitude
                                                                          longitude:longitude
                                                                              title:title];
    
    NIMMessage *message= [[NIMMessage alloc] init];
    message.messageObject= locationObject;
    
    NSDictionary *remoteExt=nil;
    if([info objectForKey:@"ext"] &&![[info objectForKey:@"ext"] isEqual:@""]){
        remoteExt=[[info objectForKey:@"ext"] isKindOfClass:[NSDictionary class]]?[info objectForKey:@"ext"] : [[info objectForKey:@"ext"] ac_JSONValue];
    }
    message.remoteExt=remoteExt;
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    [self.uexNIMMgr.SDK.chatManager sendMessage:message toSession:session error:nil];
}
-(void) sendFile:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info) = inArguments;
    if([info objectForKey:@"filePath"]==[NSNull null] || [[info objectForKey:@"filePath"] isEqual:@""]){
        return;
    }
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    NSString *filePath=[info objectForKey:@"filePath"];
    
    NIMFileObject *videoObject = [[NIMFileObject alloc] initWithSourcePath:[self absPath:filePath]];
    videoObject.displayName=[info objectForKey:@"displayName"];
    
    NIMMessage *message         = [[NIMMessage alloc] init];
    message.messageObject       = videoObject;
    
    NSDictionary *remoteExt=nil;
    if([info objectForKey:@"ext"] &&![[info objectForKey:@"ext"] isEqual:@""]){
        remoteExt=[[info objectForKey:@"ext"] isKindOfClass:[NSDictionary class]]?[info objectForKey:@"ext"] : [[info objectForKey:@"ext"] ac_JSONValue];
    }
    message.remoteExt=remoteExt;
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    [self.uexNIMMgr.SDK.chatManager sendMessage:message toSession:session error:nil];
}
-(void)resendMessage:(NSMutableArray *)inArguments{
    if (!self.uexNIMMgr.message) {
        return;
    }
    BOOL result=[self.uexNIMMgr.SDK.chatManager resendMessage:self.uexNIMMgr.message error:nil];
    if(result){
        self.uexNIMMgr.message=nil;
    }
    NSMutableDictionary *resultDic=[NSMutableDictionary dictionary];
    [resultDic setValue:[NSNumber numberWithBool:result] forKey:@"result"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbResendMessage" parameter:resultDic];
}
-(NIMSession *) sessionWithType:(NSString *)sessionType sessionId:(NSString *)sessionId{
    NIMSession *session;
    if([sessionType isKindOfClass:[NSNull class]] || [sessionId isKindOfClass:[NSNull class]]){
        return nil;
    }
    if([sessionType isEqual:@"1"] || [sessionType integerValue]==1){
        session= [NIMSession session:sessionId type:NIMSessionTypeTeam];
    }
    else if([sessionType isEqual:@"2"] || [sessionType integerValue]==2){
        session= [NIMSession session:sessionId type:NIMSessionTypeChatroom];
    }
    else{
        session= [NIMSession session:sessionId type:NIMSessionTypeP2P];
    }
    return session;
}
-(void) fetchMessageAttachment:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    if([info objectForKey:@"messageId"]){
        NSString *messageId=[info objectForKey:@"messageId"];
        NSArray *messageIds=[NSArray arrayWithObject:messageId];
        NSArray *messages=[self.uexNIMMgr.SDK.conversationManager messagesInSession:session messageIds:messageIds];
        if(messages.count>0){
            NIMMessage *SMessage=nil;
            for(NIMMessage *AMessage in messages){
                SMessage=AMessage;
            }
            [self.uexNIMMgr.SDK.chatManager fetchMessageAttachment:SMessage error:nil];
        }
    }
}

-(void)allRecentSession:(NSMutableArray *)inArguments{
    NSMutableArray* sessionArr=[self.uexNIMMgr.SDK.conversationManager.allRecentSessions mutableCopy];
    NSMutableArray *result=[NSMutableArray array];
    for(NIMRecentSession *session in sessionArr ){
        [result addObject:[self.uexNIMMgr analyzeWithNIMRecentSession:session]];
    }
    
    [self.uexNIMMgr callBackJsonWithFunction:@"cbAllRecentSession" parameter:@{@"sessions":result}];
}
-(void) deleteMessage:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *messageId=[info objectForKey:@"messageId"];
    NSMutableArray *messageIds=[NSMutableArray array];
    [messageIds addObject:messageId];
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    NSArray *messageArr=  [self.uexNIMMgr.SDK.conversationManager messagesInSession:session messageIds:messageIds];
    if(messageArr.count>0){
        NIMMessage *message=messageArr[0];
        [self.uexNIMMgr.SDK.conversationManager deleteMessage:message];
    }
}
-(void) deleteAllmessagesInSession:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;
    BOOL removeRecentSession=YES;
    if([info objectForKey:@"removeRecentSession"]){
        removeRecentSession=[[info objectForKey:@"removeRecentSession"] boolValue];
    }
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    [self.uexNIMMgr.SDK.conversationManager deleteAllmessagesInSession:session removeRecentSession:removeRecentSession];
}
-(void) deleteRecentSession:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NIMSessionType sessionType=NIMSessionTypeP2P;
    if([[info objectForKey:@"sessionType"] integerValue]==1){
        sessionType=NIMSessionTypeTeam;
    }
    else if([[info objectForKey:@"sessionType"] integerValue]==2){
        sessionType=NIMSessionTypeChatroom;
    }
    NSMutableArray* sessionArr=[self.uexNIMMgr.SDK.conversationManager.allRecentSessions mutableCopy];
    for(NIMRecentSession *session in sessionArr ){
        if([session.session.sessionId isEqual:sessionId] && session.session.sessionType==sessionType){
            [self.uexNIMMgr.SDK.conversationManager deleteRecentSession:session];
            break;
        }
    }
}
-(void) deleteAllMessages:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    BOOL removeRecentSession=YES;
    if([info objectForKey:@"removeRecentSession"]){
        removeRecentSession=[[info objectForKey:@"removeRecentSession"] boolValue];
    }
    [self.uexNIMMgr.SDK.conversationManager deleteAllMessages:removeRecentSession];
}
-(void) allUnreadCount:(NSMutableArray *)inArguments{
    NSInteger count=[self.uexNIMMgr.SDK.conversationManager allUnreadCount];
     NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [result setValue:@(count) forKey:@"count"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbAllUnreadCount" parameter:result];
}

-(void) markAllMessagesReadInSession:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    [self.uexNIMMgr.SDK.conversationManager markAllMessagesReadInSession:session];
}

#pragma mark -4.历史记录
-(void) fetchMessageHistory:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    NSInteger limit=100;
    if([info objectForKey:@"limit"]){
        limit=[[info objectForKey:@"limit"] integerValue];
    }
    NSTimeInterval startTime=0;
    if([info objectForKey:@"startTime"]){
        startTime=[[info objectForKey:@"startTime"] doubleValue];
    }
    NSTimeInterval endTime=0;
    if([info objectForKey:@"endTime"]){
        endTime=[[info objectForKey:@"endTime"] doubleValue];
    }
    NIMHistoryMessageSearchOption *searchOpt = [[NIMHistoryMessageSearchOption alloc] init];
    searchOpt.startTime  = startTime;
    searchOpt.endTime    = endTime;
    searchOpt.currentMessage = nil;
    searchOpt.sync       = YES;
    searchOpt.limit      = limit;
    searchOpt.order=NIMMessageSearchOrderDesc;
    if([info objectForKey:@"order"] && [[info objectForKey:@"order"] integerValue]==1){
        searchOpt.order=NIMMessageSearchOrderAsc;
    }
    if([info objectForKey:@"syno"]){
        if([[info objectForKey:@"syno"] boolValue]==NO){
            searchOpt.sync       = NO;
        }
    }
    
    
    [self.uexNIMMgr.SDK.conversationManager fetchMessageHistory:session option:searchOpt result:^(NSError *error, NSArray *messages) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if(error){
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1))];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            NSMutableArray *msgList =[NSMutableArray array];
            for(NIMMessage *message in messages){
                [msgList addObject:[self.uexNIMMgr analyzeWithNIMMessage:message]];
            }
            [result setValue:msgList forKey:@"messages"];
            [func executeWithArguments:ACArgsPack(@(0),[@{@"messages":msgList} copy])];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbFetchMessageHistory" parameter:result];
    }];
}
-(void) messagesInSession:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    NSInteger limit=100;
    if([info objectForKey:@"limit"]){
        limit=[[info objectForKey:@"limit"] integerValue];
    }
    NIMMessage *SMessage=nil;
    if([info objectForKey:@"messageId"]){
        NSString *messageId=[info objectForKey:@"messageId"];
        NSArray *messageIds=[NSArray arrayWithObject:messageId];
        NSArray *messages=[self.uexNIMMgr.SDK.conversationManager messagesInSession:session messageIds:messageIds];
        for(NIMMessage *AMessage in messages){
            SMessage=AMessage;
        }
    }
    
    NSArray *messageArr= [self.uexNIMMgr.SDK.conversationManager messagesInSession:session message:SMessage limit:limit];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSMutableArray *msgList =[NSMutableArray array];
    if(messageArr.count>0){
        for(NIMMessage *message in messageArr){
            [msgList addObject:[self.uexNIMMgr analyzeWithNIMMessage:message]];
        }
    }
    [result setValue:msgList forKey:@"messages"];
    
    [self.uexNIMMgr callBackJsonWithFunction:@"cbMessagesInSession" parameter:result];
}
-(void) searchMessages:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    NSInteger limit=100;
    if([info objectForKey:@"limit"]){
        limit=[[info objectForKey:@"limit"] integerValue];
    }
    NSTimeInterval startTime=0;
    if([info objectForKey:@"startTime"]){
        startTime=[[info objectForKey:@"startTime"] doubleValue];
    }
    NSTimeInterval endTime=0;
    if([info objectForKey:@"endTime"]){
        endTime=[[info objectForKey:@"endTime"] doubleValue];
    }
    NSString *keyword=@"";
    if([info objectForKey:@"keyword"]){
        keyword=[info objectForKey:@"keyword"];
    }
    NSMutableArray *fromIds=[NSMutableArray array];
    if([info objectForKey:@"fromIds"]){
        fromIds=[[info objectForKey:@"fromIds"] ac_JSONValue];
    }
    NIMMessageSearchOption *searchOpt = [[NIMMessageSearchOption alloc] init];
    searchOpt.startTime  = startTime;
    searchOpt.endTime    = endTime;
    searchOpt.limit      = limit;
    searchOpt.searchContent=keyword;
    searchOpt.fromIds=fromIds;
    searchOpt.order=NIMMessageSearchOrderDesc;
    
    [self.uexNIMMgr.SDK.conversationManager searchMessages:session option:searchOpt result:^(NSError *error, NSArray *messages) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if(error){
            [result setValue:@(error.code) forKey:@"error"];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            NSMutableArray *msgList =[NSMutableArray array];
            for(NIMMessage *message in messages){
                [msgList addObject:[self.uexNIMMgr analyzeWithNIMMessage:message]];
            }
            [result setValue:msgList forKey:@"messages"];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbSearchMessages" parameter:result];
    }];
}

#pragma mark -5.语音录制及回放
-(NSNumber*) switchAudioOutputDevice:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return @(NO);
    }
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSInteger outputDevice=0;
    if([info objectForKey:@"outputDevice"]){
        outputDevice=[[info objectForKey:@"outputDevice"] integerValue];
    }
    NSMutableDictionary *resultDic=[NSMutableDictionary dictionary];
    BOOL result;
    if(outputDevice==1){
        result=[self.uexNIMMgr.SDK.mediaManager switchAudioOutputDevice:NIMAudioOutputDeviceSpeaker];
    }
    else{
        result=[self.uexNIMMgr.SDK.mediaManager switchAudioOutputDevice:NIMAudioOutputDeviceReceiver];
    }
    [resultDic setValue:[NSNumber numberWithBool:result] forKey:@"result"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbSwitchAudioOutputDevice" parameter:resultDic];
    return @(result);
}
-(NSNumber*) isPlaying:(NSMutableArray *)inArguments{
    NSMutableDictionary *resultDic=[NSMutableDictionary dictionary];
    BOOL result=[self.uexNIMMgr.SDK.mediaManager isPlaying];
    [resultDic setValue:[NSNumber numberWithBool:result] forKey:@"result"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbIsPlaying" parameter:resultDic];
    return @(result);
}
-(void) playAudio:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info) = inArguments;
    if([info objectForKey:@"filePath"]==[NSNull null] || [[info objectForKey:@"filePath"] isEqual:@""]){
        return;
    }
    NSString *filePath=[info objectForKey:@"filePath"];
    [self.uexNIMMgr playAudio:[self absPath:filePath]];
}
-(void) stopPlay:(NSMutableArray *)inArguments{
    [self.uexNIMMgr.SDK.mediaManager stopPlay];
}

-(NSNumber*) isRecording:(NSMutableArray *)inArguments{
    NSMutableDictionary *resultDic=[NSMutableDictionary dictionary];
    BOOL result=[self.uexNIMMgr.SDK.mediaManager isRecording];
    [resultDic setValue:[NSNumber numberWithBool:result] forKey:@"result"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbIsRecording" parameter:resultDic];
    return @(result);
}
-(void) recordAudioForDuration:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSInteger duration;
    if ([info objectForKey:@"duration"]) {
        duration=[[info objectForKey:@"duration"] integerValue];
    }
    if([info objectForKey:@"updateTime"]){
        self.uexNIMMgr.SDK.mediaManager.recordProgressUpdateTimeInterval=[[info objectForKey:@"updateTime"] floatValue];
    }
    
//    [self.uexNIMMgr.SDK.mediaManager recordAudioForDuration:duration withDelegate:self.uexNIMMgr];
    [self.uexNIMMgr.SDK.mediaManager recordForDuration:duration];
}
-(void) stopRecord:(NSMutableArray *)inArguments{
    [self.uexNIMMgr.SDK.mediaManager stopRecord];
}
-(void) cancelRecord:(NSMutableArray *)inArguments{
    [self.uexNIMMgr.SDK.mediaManager cancelRecord];
}
#pragma mark -6.群组功能

-(void) allMyTeams:(NSMutableArray *)inArguments{
    ACArgsUnpack(ACJSFunctionRef *func) = inArguments;
    NSArray *allMyTeams= [self.uexNIMMgr.SDK.teamManager allMyTeams];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSMutableArray *teams=[NSMutableArray array];
    if(allMyTeams.count>0){
        for (NIMTeam *team in allMyTeams) {
            [teams addObject:[self.uexNIMMgr analyzeWithNIMTeam:team]];
        }
    }
    [result setValue:teams forKey:@"teams"];
    NSNumber*error = @(1);
    if (teams && teams.count > 0) {
        error =@(0);
    }
    [self.uexNIMMgr callBackJsonWithFunction:@"cbAllMyTeams" parameter:result];
    [func executeWithArguments:ACArgsPack(error,result)];
}
-(void) teamById:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NIMTeam *team=[self.uexNIMMgr.SDK.teamManager teamById:teamId];
    NSNumber*error = @(1);
    if (team) {
        error =@(0);
    }
    NSMutableDictionary *result=[self.uexNIMMgr analyzeWithNIMTeam:team];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbTeamById" parameter:@{@"team":result}];
    [func executeWithArguments:ACArgsPack(error,result)];
    
}
-(void) fetchTeamInfo:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    [self.uexNIMMgr.SDK.teamManager fetchTeamInfo:teamId completion:^(NSError *error, NIMTeam *team) {
        if(error){
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),error.localizedDescription)];
        }
        else{
            NSMutableDictionary *dic = [self.uexNIMMgr analyzeWithNIMTeam:team];
            [result setValue:@"" forKey:@"error"];
            [result setValue:dic forKey:@"team"];
            [func executeWithArguments:ACArgsPack(@(0),@{@"team":dic})];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbFetchTeamInfo" parameter:result];
    }];
    
}
-(void) createTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *name=@"";
    if([info objectForKey:@"name"]){
        name=[info objectForKey:@"name"];
    }
    NIMTeamType type=NIMTeamTypeNormal;
    if([info objectForKey:@"type"]){
        if([[info objectForKey:@"type"] integerValue]==1){
            type=NIMTeamTypeAdvanced;
        }
    }
    NIMTeamJoinMode joinMode=NIMTeamJoinModeNoAuth;
    if([info objectForKey:@"joinMode"]){
        switch ([[info objectForKey:@"joinMode"] integerValue]) {
            case 1:
                joinMode=NIMTeamJoinModeNeedAuth;
                break;
            case 2:
                joinMode=NIMTeamJoinModeRejectAll;
                break;
                
            default:
                break;
        }
    }
    NSString *postscript=@"";
    if([info objectForKey:@"postscript"]){
        postscript=[info objectForKey:@"postscript"];
    }
    NSString *intro=@"";
    if([info objectForKey:@"intro"]){
        intro=[info objectForKey:@"intro"];
    }
    NSString *announcement=@"";
    if([info objectForKey:@"announcement"]){
        announcement=[info objectForKey:@"announcement"];
    }
    
    NIMCreateTeamOption *option = [[NIMCreateTeamOption alloc] init];
    option.name=name;
    option.type=type;
    option.joinMode=joinMode;
    option.postscript=postscript;
    option.intro=intro;
    option.announcement=announcement;
    
    NSArray *users=[[info objectForKey:@"users"] ac_JSONValue];
    [self.uexNIMMgr.SDK.teamManager createTeam:option users:users completion:^(NSError *error, NSString *teamId) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        [result setValue:teamId forKey:@"teamId"];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbCreateTeam" parameter:result];
    }];

}
-(void) addUsers:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSArray *users=[[info objectForKey:@"users"] ac_JSONValue];
    NSString *postscript=@"";
    if([info objectForKey:@"postscript"]){
        postscript=[info objectForKey:@"postscript"];
    }
    [self.uexNIMMgr.SDK.teamManager addUsers:users toTeam:teamId postscript:postscript completion:^(NSError *error, NSArray *members) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbAddUsers" parameter:result];
    }];
}
-(void) acceptInviteWithTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *invitorId=[info objectForKey:@"invitorId"];
    [self.uexNIMMgr.SDK.teamManager acceptInviteWithTeam:teamId invitorId:invitorId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbAcceptInviteWithTeam" parameter:result];
    }];
}
-(void) rejectInviteWithTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *invitorId=[info objectForKey:@"invitorId"];
    NSString *rejectReason=[info objectForKey:@"rejectReason"];
    [self.uexNIMMgr.SDK.teamManager rejectInviteWithTeam:teamId invitorId:invitorId rejectReason:rejectReason completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbRejectInviteWithTeam" parameter:result];
    }];
}
-(void) applyToTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *message=[info objectForKey:@"message"];
    [self.uexNIMMgr.SDK.teamManager applyToTeam:teamId message:message completion:^(NSError *error,NIMTeamApplyStatus applyStatus) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        [result setValue:@(applyStatus) forKey:@"applyStatus"];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbApplyToTeam" parameter:result];
    }];
}
-(void) passApplyToTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *userId=[info objectForKey:@"userId"];
    [self.uexNIMMgr.SDK.teamManager passApplyToTeam:teamId userId:userId completion:^(NSError *error,NIMTeamApplyStatus applyStatus) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        [result setValue:@(applyStatus) forKey:@"applyStatus"];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbPassApplyToTeam" parameter:result];
    }];
}
-(void) rejectApplyToTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *userId=[info objectForKey:@"userId"];
    NSString *rejectReason=[info objectForKey:@"rejectReason"];
    [self.uexNIMMgr.SDK.teamManager rejectApplyToTeam:teamId userId:userId rejectReason:rejectReason completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbRejectApplyToTeam" parameter:result];
    }];
}
-(void) updateTeamName:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *teamName=[info objectForKey:@"teamName"];
    [self.uexNIMMgr.SDK.teamManager updateTeamName:teamName teamId:teamId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateTeamName" parameter:result];
    }];
}
-(void) updateTeamIntro:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *intro=[info objectForKey:@"intro"];
    [self.uexNIMMgr.SDK.teamManager updateTeamIntro:intro teamId:teamId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateTeamIntro" parameter:result];
    }];
}
-(void) updateTeamAnnouncement:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *announcement=[info objectForKey:@"announcement"];
    [self.uexNIMMgr.SDK.teamManager updateTeamAnnouncement:announcement teamId:teamId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateTeamAnnouncement" parameter:result];
    }];
}
-(void) updateTeamJoinMode:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NIMTeamJoinMode joinMode;
    if([info objectForKey:@"joinMode"]){
        switch ([[info objectForKey:@"joinMode"] integerValue]) {
            case 0:
                joinMode=NIMTeamJoinModeNoAuth;
                break;
            case 1:
                joinMode=NIMTeamJoinModeNeedAuth;
                break;
            case 2:
                joinMode=NIMTeamJoinModeRejectAll;
                break;
                
            default:
                return;
                break;
        }
    }
    [self.uexNIMMgr.SDK.teamManager updateTeamJoinMode:joinMode teamId:teamId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateTeamJoinMode" parameter:result];
    }];
}
-(void) addManagersToTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSArray *users=[[info objectForKey:@"users"] ac_JSONValue];
    
    [self.uexNIMMgr.SDK.teamManager addManagersToTeam:teamId users:users completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbAddManagersToTeam" parameter:result];
    }];
}
-(void) removeManagersFromTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
  
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSArray *users=[[info objectForKey:@"users"] ac_JSONValue];
    
    [self.uexNIMMgr.SDK.teamManager removeManagersFromTeam:teamId users:users completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbRemoveManagersFromTeam" parameter:result];
    }];
}
-(void) transferManagerWithTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *newOwnerId=[info objectForKey:@"newOwnerId"];
    BOOL isLeave=NO;
    if([[info objectForKey:@"isLeave"] boolValue]){
        isLeave=YES;
    }
    
    [self.uexNIMMgr.SDK.teamManager transferManagerWithTeam:teamId newOwnerId:newOwnerId isLeave:isLeave completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbTransferManagerWithTeam" parameter:result];
    }];
}
-(void) fetchTeamMembers:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    [self.uexNIMMgr.SDK.teamManager fetchTeamMembers:teamId completion:^(NSError *error, NSArray *members) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        NSMutableArray *membersArr=[NSMutableArray array];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            for (NIMTeamMember *member in members) {
                [membersArr addObject:[self.uexNIMMgr analyzeWithNIMTeamMember:member]];
            }
            [result setValue:membersArr forKey:@"members"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        
        [self.uexNIMMgr callBackJsonWithFunction:@"cbFetchTeamMembers" parameter:result];
    }];
}
-(void) quitTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] ac_JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    [self.uexNIMMgr.SDK.teamManager quitTeam:teamId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbQuitTeam" parameter:result];
    }];
}
-(void) kickUsers:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] ac_JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSArray *users=[[info objectForKey:@"users"] ac_JSONValue];
    [self.uexNIMMgr.SDK.teamManager kickUsers:users fromTeam:teamId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbKickUsers" parameter:result];
    }];
}
-(void) dismissTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] ac_JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    [self.uexNIMMgr.SDK.teamManager dismissTeam:teamId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbDismissTeam" parameter:result];
    }];
}
-(void) updateNotifyStateForTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] ac_JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    BOOL notify=NO;
    if([[info objectForKey:@"notify"] boolValue]){
        notify=YES;
    }
    [self.uexNIMMgr.SDK.teamManager updateNotifyState:notify inTeam:teamId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateNotifyStateForTeam" parameter:result];
    }];
}
-(NSNumber*) notifyForNewMsgForTeam:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return @(NO);
    }
    //id info=[inArguments[0] ac_JSONValue];
     ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *teamId = [info objectForKey:@"teamId"];
    BOOL notifyForNewMsg=[self.uexNIMMgr.SDK.teamManager notifyForNewMsg:teamId];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if (notifyForNewMsg) {
        [result setValue:[NSNumber numberWithBool:YES] forKey:@"result"];
    }
    else{
        [result setValue:[NSNumber numberWithBool:NO] forKey:@"result"];
    }
    [self.uexNIMMgr callBackJsonWithFunction:@"cbNotifyForNewMsgForTeam" parameter:result];
    return @(notifyForNewMsg);
}
-(void) updateTeamCustomInfo:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *teamId=[info objectForKey:@"teamId"];
    NSString *customInfo=[info objectForKey:@"info"];
    [self.uexNIMMgr.SDK.teamManager updateTeamCustomInfo:customInfo teamId:teamId  completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateTeamCustomInfo" parameter:result];
    }];
}


#pragma mark -7.系统通知
-(void) fetchSystemNotifications:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSInteger limit=0;
    if([info objectForKey:@"limit"]){
        limit=[[info objectForKey:@"limit"] integerValue];
    }
    NSArray *notifications=[[self.uexNIMMgr.SDK systemNotificationManager] fetchSystemNotifications:nil limit:limit];
    NSMutableArray *result=[NSMutableArray array];
    NSNumber *error = @(1);
    if([notifications count]){
        error = @(0);
        for (NIMSystemNotification *notification in notifications) {
            [result addObject:[self.uexNIMMgr analyzeWithSystemNotification:notification]];
        }
        [func executeWithArguments:ACArgsPack(error,@{@"notifications":result})];
    }else{
         [func executeWithArguments:ACArgsPack(error)];
    }
    [self.uexNIMMgr callBackJsonWithFunction:@"cbFetchSystemNotifications" parameter:@{@"notifications":result}];
    
}
-(NSNumber*) allNotificationsUnreadCount:(NSMutableArray *)inArguments{
    NSInteger count=[[self.uexNIMMgr.SDK systemNotificationManager] allUnreadCount];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbAllNotificationsUnreadCount" parameter:@{@"count":@(count)}];
    return @(count);
}
-(void) deleteAllNotifications:(NSMutableArray *)inArguments{
    [[self.uexNIMMgr.SDK systemNotificationManager] deleteAllNotifications];
}
-(NSNumber*) markAllNotificationsAsRead:(NSMutableArray *)inArguments{
    if ([[self.uexNIMMgr.SDK systemNotificationManager] respondsToSelector:@selector(markAllNotificationsAsRead)]) {
        [[self.uexNIMMgr.SDK systemNotificationManager] markAllNotificationsAsRead];
        [self.uexNIMMgr callBackJsonWithFunction:@"cbMarkAllNotificationsAsRead" parameter:@{@"result":@(YES)}];
        return @(YES);
    }else{
        [self.uexNIMMgr callBackJsonWithFunction:@"cbMarkAllNotificationsAsRead" parameter:@{@"result":@(NO)}];
        return @(NO);
    }
    
    
}
-(NSNumber*) sendCustomNotification:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return @(NO);
    }
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *sessionId=[info objectForKey:@"sessionId"];
    NSString *sessionType=[info objectForKey:@"sessionType"];
    NIMSession *session=[self sessionWithType:sessionType sessionId:sessionId];
    
    NIMCustomSystemNotification *notification = [[NIMCustomSystemNotification alloc] initWithContent:[info objectForKey:@"content"]];
    notification.apnsContent = [info objectForKey:@"apnsContent"];
    if([info objectForKey:@"sendToOnlineUsersOnly"]){
        if([[info objectForKey:@"sendToOnlineUsersOnly"] boolValue]==NO){
            notification.sendToOnlineUsersOnly = NO;
        }
    }
    
    NIMCustomSystemNotificationSetting *setting = [[NIMCustomSystemNotificationSetting alloc] init];
    if([info objectForKey:@"shouldBeCounted"]){
        if([[info objectForKey:@"shouldBeCounted"] boolValue]==NO){
            setting.shouldBeCounted = NO;
        }
    }
    if([info objectForKey:@"apnsEnabled"]){
        if([[info objectForKey:@"apnsEnabled"] boolValue]==NO){
            setting.apnsEnabled = NO;
        }
    }
    if([info objectForKey:@"apnsWithPrefix"]){
        if([[info objectForKey:@"apnsWithPrefix"] boolValue]==YES){
            setting.apnsWithPrefix = YES;
        }
    }
    notification.setting = setting;
    __block BOOL isSuccess;
    [[self.uexNIMMgr.SDK systemNotificationManager] sendCustomNotification:notification toSession:session completion:^(NSError *error) {
        if(error){
            [self.uexNIMMgr callBackJsonWithFunction:@"cbSendCustomNotification" parameter:@{@"error":@(error.code)}];
            isSuccess = NO;
        }
        else{
            [self.uexNIMMgr callBackJsonWithFunction:@"cbSendCustomNotification" parameter:@{@"error":@""}];
            isSuccess = YES;
        }
    }];
    return @(isSuccess);
}
#pragma mark -8.APNS
-(void)registerAPNS:(NSMutableArray *)inArguments{
    ACArgsUnpack(ACJSFunctionRef *func) = inArguments;
    self.registerAPNSFunc = func;
    UIApplication *application = [UIApplication sharedApplication];
    application.applicationIconBadgeNumber = 0;
    
    if([application respondsToSelector:@selector(registerUserNotificationSettings:)])
    {
        UIUserNotificationType notificationTypes = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
        [application registerUserNotificationSettings:settings];
    }
    
#if !TARGET_IPHONE_SIMULATOR
    
    if ([application respondsToSelector:@selector(registerForRemoteNotifications)]) {
        [application registerForRemoteNotifications];
    }else{
        UIRemoteNotificationType notificationTypes = UIRemoteNotificationTypeBadge |
        UIRemoteNotificationTypeSound |
        UIRemoteNotificationTypeAlert;
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:notificationTypes];
    }
#endif
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(NIMRegisterAPNsFail:) name:@"NIMRegisterAPNsFail" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(NIMRegisterAPNsSucceed:) name:@"NIMRegisterAPNsSucceed" object:nil];
}
-(void)NIMRegisterAPNsSucceed:(NSNotification *)notif{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[NSNumber numberWithBool:YES] forKey:@"result"];
    [dict setValue:@"" forKey:@"error"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbRegisterAPNS" parameter:dict];
    [self.registerAPNSFunc executeWithArguments:ACArgsPack(@(0))];
    self.registerAPNSFunc = nil;
    
}
-(void)NIMRegisterAPNsFail:(NSNotification *)notif{
    NSError *error =[notif.userInfo objectForKey:@"error"];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[NSNumber numberWithBool:NO] forKey:@"result"];
    [dict setValue:@(error.code) forKey:@"error"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbRegisterAPNS" parameter:dict];
    [self.registerAPNSFunc executeWithArguments:ACArgsPack(@(1),@(error.code))];
    self.registerAPNSFunc = nil;
}

+ (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    [[NIMSDK sharedSDK] updateApnsToken:deviceToken];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:deviceToken forKey:@"deviceToken"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NIMRegisterAPNsSucceed" object:nil userInfo:dict];
}
+ (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:error forKey:@"error"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NIMRegisterAPNsFail" object:nil userInfo:dict];
}
-(void)getApnsSetting:(NSMutableArray *)inArguments{
    ACArgsUnpack(ACJSFunctionRef *func) = inArguments;
    NIMPushNotificationSetting *setting =  [[[NIMSDK sharedSDK] apnsManager] currentSetting];
    NSNumber *error = @(1);
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if (setting) {
        error = @(0);
        [result setValue:@(setting.type) forKey:@"type"];
        [result setValue:@(setting.noDisturbing) forKey:@"noDisturbing"];
        [result setValue:@(setting.noDisturbingStartH) forKey:@"noDisturbingStartH"];
        [result setValue:@(setting.noDisturbingStartM) forKey:@"noDisturbingStartM"];
        [result setValue:@(setting.noDisturbingEndH) forKey:@"noDisturbingEndH"];
        [result setValue:@(setting.noDisturbingEndM) forKey:@"noDisturbingEndM"];
        [func executeWithArguments:ACArgsPack(error,result)];
    } else {
        [func executeWithArguments:ACArgsPack(error)];
    }
    [self.uexNIMMgr callBackJsonWithFunction:@"cbGetApnsSetting" parameter:result];
    
    
    
}
-(void) updateApnsSetting:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NIMPushNotificationSetting *setting=[[NIMPushNotificationSetting alloc]init];
    if([info objectForKey:@"type"]){
        setting.type=[[info objectForKey:@"type"] integerValue];
    }
    if([info objectForKey:@"noDisturbing"]){
        setting.noDisturbing=[[info objectForKey:@"noDisturbing"] boolValue];
    }
    if([info objectForKey:@"noDisturbingStartH"]){
        setting.noDisturbingStartH=[[info objectForKey:@"noDisturbingStartH"] integerValue];
    }
    if([info objectForKey:@"noDisturbingStartM"]){
        setting.noDisturbingStartM=[[info objectForKey:@"noDisturbingStartM"] integerValue];
    }
    if([info objectForKey:@"noDisturbingEndH"]){
        setting.noDisturbingEndH=[[info objectForKey:@"noDisturbingEndH"] integerValue];
    }
    if([info objectForKey:@"noDisturbingEndM"]){
        setting.noDisturbingEndM=[[info objectForKey:@"noDisturbingEndM"] integerValue];
    }
    [[self.uexNIMMgr.SDK apnsManager] updateApnsSetting:setting completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateApnsSetting" parameter:result];
    }];
    
}
#pragma mark -9.用户资料托管
-(void) userInfo:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *userId=[info objectForKey:@"userId"];
    NIMUser *user= [[self.uexNIMMgr.SDK userManager] userInfo:userId];
    if (user) {
        NSMutableDictionary *result=[self.uexNIMMgr analyzeWithNIMUser:user];
        [func executeWithArguments:ACArgsPack(@(0),result)];
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUserInfo" parameter:result];
    }else{
        [func executeWithArguments:ACArgsPack(@(1),@"uesr is not exist")];
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUserInfo" parameter:nil];
    }
    
}
-(void) fetchUserInfos:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSArray *userIds=[info objectForKey:@"userIds"];
    
    [self.uexNIMMgr.SDK.userManager fetchUserInfos:userIds completion:^(NSArray *users, NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        NSMutableArray *userArr=[NSMutableArray array];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            if([users count]){
               for(NIMUser *user in users){
                   [userArr addObject:[self.uexNIMMgr analyzeWithNIMUser:user]];
               }
            }
            [result setValue:userArr forKey:@"users"];
             [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbFetchUserInfos" parameter:result];
    }];
}
-(void) updateMyUserInfo:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSDictionary *userInfo=@{
               @(NIMUserInfoUpdateTagNick):[info objectForKey:@"nickname"],
               @(NIMUserInfoUpdateTagAvatar):[info objectForKey:@"avatar"],
               @(NIMUserInfoUpdateTagSign):[info objectForKey:@"sign"],
               @(NIMUserInfoUpdateTagGender):@([[info objectForKey:@"gender"] integerValue]),
               @(NIMUserInfoUpdateTagEmail):[info objectForKey:@"email"],
               @(NIMUserInfoUpdateTagBirth):[info objectForKey:@"birth"],
               @(NIMUserInfoUpdateTagMobile):[info objectForKey:@"mobile"],
               @(NIMUserInfoUpdateTagExt):[info objectForKey:@"ext"],
               };
    [self.uexNIMMgr.SDK.userManager updateMyUserInfo:userInfo completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateMyUserInfo" parameter:result];
    }];
    
}
#pragma mark -10.用户关系托管
-(void) myFriends:(NSMutableArray *)inArguments{
    ACArgsUnpack(ACJSFunctionRef*func) = inArguments;
    NSArray *users= [[self.uexNIMMgr.SDK userManager] myFriends];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSMutableArray *userArr=[NSMutableArray array];
    if([users count]){
        for(NIMUser *user in users){
            [userArr addObject:[self.uexNIMMgr analyzeWithNIMUser:user]];
        }
        [result setValue:userArr forKey:@"users"];
         [func executeWithArguments:ACArgsPack(@(0),result)];
    }else{
         [func executeWithArguments:ACArgsPack(@(1))];
    }
    [self.uexNIMMgr callBackJsonWithFunction:@"cbMyFriends" parameter:result];
    
}
-(void) requestFriend:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NIMUserOperation operation;
    if([info objectForKey:@"operation"]){
        switch ([[info objectForKey:@"operation"] integerValue]) {
            case 1:
                operation=NIMUserOperationAdd;
                break;
            case 2:
                operation=NIMUserOperationRequest;
                break;
            case 3:
                operation=NIMUserOperationVerify;
                break;
            case 4:
                operation=NIMUserOperationReject;
                break;
            default:
                return;
                break;
        }
    }
    NIMUserRequest *request = [[NIMUserRequest alloc] init];
    request.userId = [info objectForKey:@"userId"];
    request.operation = operation;
    request.message=[info objectForKey:@"message"];
    [self.uexNIMMgr.SDK.userManager requestFriend:request completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbRequestFriend" parameter:result];
    }];
}
-(void) deleteFriend:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *userId = [info objectForKey:@"userId"];
    [self.uexNIMMgr.SDK.userManager deleteFriend:userId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbDeleteFriend" parameter:result];
    }];
}
-(void) myBlackList:(NSMutableArray *)inArguments{
    NSArray *users= [[self.uexNIMMgr.SDK userManager] myBlackList];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSMutableArray *userArr=[NSMutableArray array];
    if([users count]){
        for(NIMUser *user in users){
            [userArr addObject:[self.uexNIMMgr analyzeWithNIMUser:user]];
        }
    }
    [result setValue:userArr forKey:@"users"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbMyBlackList" parameter:result];
}
-(void) addToBlackList:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *userId = [info objectForKey:@"userId"];
    [self.uexNIMMgr.SDK.userManager addToBlackList:userId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbAddToBlackList" parameter:result];
    }];
}
-(void) removeFromBlackBlackList:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *userId = [info objectForKey:@"userId"];
    [self.uexNIMMgr.SDK.userManager removeFromBlackBlackList:userId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbRemoveFromBlackBlackList" parameter:result];
    }];
}
-(void) isUserInBlackList:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *userId = [info objectForKey:@"userId"];
    BOOL isUserInBlackList=[self.uexNIMMgr.SDK.userManager isUserInBlackList:userId];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if (isUserInBlackList) {
        [result setValue:[NSNumber numberWithBool:YES] forKey:@"result"];
        [func executeWithArguments:ACArgsPack(@(0))];
    }
    else{
        [result setValue:[NSNumber numberWithBool:NO] forKey:@"result"];
        [func executeWithArguments:ACArgsPack(@(1))];
    }
    [self.uexNIMMgr callBackJsonWithFunction:@"cbIsUserInBlackList" parameter:result];
}
-(void) myMuteUserList:(NSMutableArray *)inArguments{
    NSArray *users= [[self.uexNIMMgr.SDK userManager] myMuteUserList];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSMutableArray *userArr=[NSMutableArray array];
    if([users count]){
        for(NIMUser *user in users){
            [userArr addObject:[self.uexNIMMgr analyzeWithNIMUser:user]];
        }
    }
    [result setValue:userArr forKey:@"users"];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbMyMuteUserList" parameter:result];
}
-(void) updateNotifyStateForUser:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *userId=[info objectForKey:@"userId"];
    BOOL notify=NO;
    if([[info objectForKey:@"notify"] boolValue]){
        notify=YES;
    }
    [self.uexNIMMgr.SDK.userManager updateNotifyState:notify forUser:userId completion:^(NSError *error) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
             [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbUpdateNotifyStateForUser" parameter:result];
    }];
}
-(void) notifyForNewMsgForUser:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *userId = [info objectForKey:@"userId"];
    BOOL notifyForNewMsg=[self.uexNIMMgr.SDK.userManager notifyForNewMsg:userId];
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    if (notifyForNewMsg) {
        [result setValue:[NSNumber numberWithBool:YES] forKey:@"result"];
        [func executeWithArguments:ACArgsPack(@(0))];
    }
    else{
        [result setValue:[NSNumber numberWithBool:NO] forKey:@"result"];
        [func executeWithArguments:ACArgsPack(@(1))];
    }
    [self.uexNIMMgr callBackJsonWithFunction:@"cbNotifyForNewMsgForUser" parameter:result];
}

#pragma mark -11.音视频通话
-(void) start:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSMutableArray *callees=[NSMutableArray array];
    if([info objectForKey:@"userIds"]){
        callees=[info objectForKey:@"userIds"] ;
    }
    NIMNetCallType type;
    switch ([[info objectForKey:@"type"] integerValue]) {
        case 1:
            type=NIMNetCallTypeAudio;
            break;
        case 2:
            type=NIMNetCallTypeVideo;
            break;
        default:
            return;
            break;
    }
    [self.uexNIMMgr.SDK.netCallManager start:callees type:type option:nil completion:^(NSError *error, UInt64 callID) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [result setValue:@"" forKey:@"callID"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbStart" parameter:result];
    }];
    
}
-(void) response:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    UInt64 callID;
    if ([info objectForKey:@"callID"]) {
        callID=[[info objectForKey:@"callID"] integerValue];
    }
    BOOL accept=YES;
    if([info objectForKey:@"accept"]){
        if([[info objectForKey:@"accept"] boolValue]==NO){
            accept=NO;
        }
    }
    [[self.uexNIMMgr.SDK netCallManager] response:callID accept:accept option:nil completion:^(NSError *error, UInt64 callID) {
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if (error) {
            [result setValue:@(error.code) forKey:@"error"];
            [result setValue:@"" forKey:@"callID"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            [result setValue:@"" forKey:@"error"];
            [result setValue:[NSString stringWithFormat:@"%llu",callID] forKey:@"callID"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbResponse" parameter:result];
    }];
}
//发送通话控制信息
-(void) control:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info) = inArguments;
    UInt64 callID = 0;
    if ([info objectForKey:@"callID"]) {
        callID=[[info objectForKey:@"callID"] integerValue];
    }
    NIMNetCallControlType type;
    if([info objectForKey:@"type"]){
        switch ([[info objectForKey:@"type"] integerValue]) {
            case 1:
                type=NIMNetCallControlTypeOpenAudio;
                break;
            case 2:
                type=NIMNetCallControlTypeCloseAudio;
                break;
            case 3:
                type=NIMNetCallControlTypeOpenVideo;
                break;
            case 4:
                type=NIMNetCallControlTypeCloseVideo;
                break;
            case 5:
                type=NIMNetCallControlTypeToVideo;
                break;
            case 6:
                type=NIMNetCallControlTypeAgreeToVideo;
                break;
            case 7:
                type=NIMNetCallControlTypeRejectToVideo;
                break;
            case 8:
                type=NIMNetCallControlTypeToAudio;
                break;
            case 9:
                type=NIMNetCallControlTypeBusyLine;
                break;
            case 10:
                type=NIMNetCallControlTypeNoCamera;
                break;
            case 11:
                type=NIMNetCallControlTypeBackground;
                break;
            case 12:
                type=NIMNetCallControlTypeFeedabck;
                break;
            case 13:
                type=NIMNetCallControlTypeStartLocalRecord;
                break;
            case 14:
                type=NIMNetCallControlTypeStopLocalRecord;
                break;
            default:
                return;
                break;
        }
    }
    [self.uexNIMMgr.SDK.netCallManager control:callID type:type];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbControl" parameter:@{@"result":@(YES)}];
}
-(void) hangup:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info) = inArguments;
    UInt64 callID = 0;
    if ([info objectForKey:@"callID"]) {
        callID=[[info objectForKey:@"callID"] integerValue];
    }
    [self.uexNIMMgr.SDK.netCallManager hangup:callID];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbHangup" parameter:@{@"result":@(YES)}];
}
-(void) currentCallID:(NSMutableArray *)inArguments{
    UInt64 callID=[self.uexNIMMgr.SDK.netCallManager currentCallID];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbCurrentCallID" parameter:@{@"callID":[NSString stringWithFormat:@"%llu",callID]}];
}
-(void) callNetStatus:(NSMutableArray *)inArguments{
    //注释掉，等android做了再改
//    NIMNetCallNetStatus netStatus=[self.uexNIMMgr.SDK.netCallManager netStatus];
//    [self.uexNIMMgr callBackJsonWithFunction:@"cbCallNetStatus" parameter:@{@"netStatus":@(netStatus)}];
}
-(void)initRemoteView:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    if(self.uexNIMMgr.remoteView){
        [self.uexNIMMgr.remoteView removeFromSuperview];
    }
    if(self.uexNIMMgr.localView){
        [self.uexNIMMgr.localView removeFromSuperview];
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info) = inArguments;
    float localViewX=0,localViewY=0,localViewW=0,localViewH=0,remoteViewX=0,remoteViewY=0,remoteViewW=0,remoteViewH=0;
    if([info objectForKey:@"localViewX"]){
        localViewX=[[info objectForKey:@"localViewX"] floatValue];
    }
    if([info objectForKey:@"localViewY"]){
        localViewY=[[info objectForKey:@"localViewY"] floatValue];
    }
    if([info objectForKey:@"localViewH"]){
        localViewH=[[info objectForKey:@"localViewH"] floatValue];
    }
    if([info objectForKey:@"localViewW"]){
        localViewW=[[info objectForKey:@"localViewW"] floatValue];
    }
    
    if([info objectForKey:@"remoteViewX"]){
        remoteViewX=[[info objectForKey:@"remoteViewX"] floatValue];
    }
    if([info objectForKey:@"remoteViewY"]){
        remoteViewY=[[info objectForKey:@"remoteViewY"] floatValue];
    }
    if([info objectForKey:@"remoteViewW"]){
        remoteViewW=[[info objectForKey:@"remoteViewW"] floatValue];
    }
    if([info objectForKey:@"remoteViewH"]){
        remoteViewH=[[info objectForKey:@"remoteViewH"] floatValue];
    }
    self.uexNIMMgr.remoteView=[[UIImageView alloc]init];
    self.uexNIMMgr.remoteView.backgroundColor=[UIColor clearColor];
    self.uexNIMMgr.remoteView.frame=CGRectMake(remoteViewX, remoteViewY, remoteViewW, remoteViewH);
    
//    self.uexNIMMgr.remoteGLView=[[NTESGLView alloc] init];
//    self.uexNIMMgr.remoteGLView.frame=self.uexNIMMgr.remoteView.frame;
//    self.uexNIMMgr.remoteGLView.backgroundColor=[UIColor clearColor];
//    [self.uexNIMMgr.remoteGLView setContentMode:UIViewContentModeScaleAspectFit];
//    self.uexNIMMgr.remoteGLView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//    [self.uexNIMMgr.remoteView addSubview:self.uexNIMMgr.remoteGLView];
    
    self.uexNIMMgr.localView=[[UIView alloc]init];
    self.uexNIMMgr.localView.frame=CGRectMake(localViewX, localViewY, localViewW, localViewH);
    self.uexNIMMgr.localView.backgroundColor=[UIColor clearColor];
    [self.uexNIMMgr.remoteView addSubview:self.uexNIMMgr.localView];
    [[self.webViewEngine webView] addSubview:self.uexNIMMgr.remoteView];
    //[EUtility brwView:meBrwView addSubview:self.uexNIMMgr.remoteView];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbInitRemoteView" parameter:@{@"result":@(YES)}];
}
-(void)removeRemoteView:(NSMutableArray *)inArguments{
    if(self.uexNIMMgr.remoteView){
        [self.uexNIMMgr.remoteView removeFromSuperview];
    }
    if(self.uexNIMMgr.localView){
        [self.uexNIMMgr.localView removeFromSuperview];
    }
    [self.uexNIMMgr callBackJsonWithFunction:@"cbRemoveRemoteView" parameter:@{@"result":@(YES)}];
}
-(void)setMute:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info) = inArguments;
    BOOL mute=[[info objectForKey:@"mute"] boolValue];
    BOOL result=[self.uexNIMMgr.SDK.netCallManager setMute:mute];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbSetMute" parameter:@{@"result":@(result)}];
}
-(void)setSpeaker:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info) = inArguments;
    BOOL useSpeaker=[[info objectForKey:@"useSpeaker"] boolValue];
    BOOL result=[self.uexNIMMgr.SDK.netCallManager setSpeaker:useSpeaker];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbSetSpeaker" parameter:@{@"result":@(result)}];
}
-(void)switchCamera:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NIMNetCallCamera camera;
    if([info objectForKey:@"camera"]){
        switch ([[info objectForKey:@"camera"] integerValue]) {
            case 1:
                camera=NIMNetCallCameraFront;
                break;
            case 2:
                camera=NIMNetCallCameraBack;
                break;
            default:
                return;
                break;
        }
    }
    [self.uexNIMMgr.SDK.netCallManager switchCamera:camera];
}
-(void)setCameraDisable:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info) = inArguments;
    BOOL disable=[[info objectForKey:@"disable"] boolValue];
    BOOL result=[self.uexNIMMgr.SDK.netCallManager setCameraDisable:disable];
    [self.uexNIMMgr callBackJsonWithFunction:@"cbSetCameraDisable" parameter:@{@"result":@(result)}];
}
-(void)startLocalRecording:(NSMutableArray *)inArguments{
    NSURL *filePath;
    int videoBitrate;
    if(inArguments.count>0){
        //id info=[inArguments[0] JSONValue];
         ACArgsUnpack(NSDictionary *info) = inArguments;
        if([info objectForKey:@"filePath"] &&![[info objectForKey:@"filePath"] isEqual:@""]){
            filePath=[NSURL URLWithString:[info objectForKey:@"filePath"]];
        }
        if([info objectForKey:@"videoBitrate"]){
            videoBitrate=[[info objectForKey:@"videoBitrate"] intValue];
        }
    }
    [self.uexNIMMgr.SDK.netCallManager startLocalRecording:filePath videoBitrate:videoBitrate];
}
-(void)stopLocalRecording:(NSMutableArray *)inArguments{
    [self.uexNIMMgr.SDK.netCallManager stopLocalRecording];
}




#pragma mark -12.实时会话（白板）
//-(void) requestRTS:(NSMutableArray *)inArguments{
//    if(inArguments.count<1){
//        return;
//    }
//    id info=[inArguments[0] JSONValue];
//    NSArray *callees=[info objectForKey:@"callees"];
//    NIMRTSOption *option;
//    option.message=@"1212121";
//    option.extendMessage=[info objectForKey:@"extendMessage"];
//    
//    [self.uexNIMMgr.SDK.rtsManager requestRTS:callees services:NIMRTSServiceReliableTransfer | NIMRTSServiceAudio option:option completion:^(NSError *error, NSString *sessionID) {
//        NSMutableDictionary *result=[NSMutableDictionary dictionary];
//        if (error) {
//            [result setValue:@(error.code) forKey:@"error"];
//            [result setValue:@"" forKey:@"sessionID"];
//        }
//        else{
//            [result setValue:@"" forKey:@"error"];
//            [result setValue:[NSString stringWithFormat:@"%@",sessionID] forKey:@"sessionId"];
//        }
//        [self.uexNIMMgr callBackJsonWithFunction:@"cbRequestRTS" parameter:result];
//    }];
//}


#pragma mark -9.聊天室
-(void)enterChatRoom:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    id extension=[info objectForKey:@"extension"];
    id notifyExtension=[info objectForKey:@"notifyExtension"];
    NSString *roomExt, *roomNotifyExt;
    if(extension && [extension isKindOfClass:[NSDictionary class]]){
        roomExt=[extension ac_JSONFragment];
    }
    else{
        roomExt=extension;
    }
    if(notifyExtension && [notifyExtension isKindOfClass:[NSDictionary class]]){
        roomNotifyExt=[notifyExtension ac_JSONFragment];
    }
    else{
        roomNotifyExt=notifyExtension;
    }
    
    NIMChatroomEnterRequest *request=[NIMChatroomEnterRequest alloc];
    request.roomId=roomId;
    request.roomExt=roomExt;
    request.roomNotifyExt=roomNotifyExt;
    request.roomNickname=[info objectForKey:@"nickName"];
    request.roomAvatar=[info objectForKey:@"avatar"];
    [self.uexNIMMgr.SDK.chatroomManager enterChatroom:request completion:^(NSError *error, NIMChatroom *chatroom, NIMChatroomMember *me) {
        if(error){
            [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbEnterChatRoom" parameter:@{@"error":@(error.code)}];
        }
        else{
             [func executeWithArguments:ACArgsPack(@(0))];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbEnterChatRoom" parameter:@{@"error":@""}];
        }
    }];
    
}
-(void)exitChatRoom:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
   
    [self.uexNIMMgr.SDK.chatroomManager exitChatroom:roomId completion:^(NSError *error) {
        if(error){
            [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbExitChatRoom" parameter:@{@"error":@(error.code)}];
        }
        else{
            [func executeWithArguments:ACArgsPack(@(0))];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbExitChatRoom" parameter:@{@"error":@""}];
        }
    }];
}
-(void)getChatRoomHistoryMsg:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    NSTimeInterval startTime=0;
    if([info objectForKey:@"startTime"]){
        startTime=[[info objectForKey:@"startTime"] doubleValue];
    }
    NSUInteger limit=10;
    if([info objectForKey:@"limit"]){
        startTime=[[info objectForKey:@"limit"] integerValue];
    }
    
    NIMHistoryMessageSearchOption *option =[NIMHistoryMessageSearchOption alloc];
    option.startTime=startTime;
    option.limit=limit;
    
    [self.uexNIMMgr.SDK.chatroomManager fetchMessageHistory:roomId option:option result:^(NSError *error, NSArray *messages) {
        NSMutableArray *msgArr=[NSMutableArray array];
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if(error){
            [result setValue:@(error.code) forKey:@"error"];
            [result setValue:@"" forKey:@"messages"];
            [func executeWithArguments:ACArgsPack(@(1),result)];
        }
        else{
            for (NIMMessage *message in messages) {
                [msgArr addObject:[self.uexNIMMgr analyzeWithNIMMessage:message]];
            }
            [result setValue:@"" forKey:@"error"];
            [result setValue:msgArr forKey:@"messages"];
            [func executeWithArguments:ACArgsPack(@(0),result)];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbGetChatRoomHistoryMsg" parameter:result];
    }];
}
-(void)getChatRoomInfo:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    
    [self.uexNIMMgr.SDK.chatroomManager fetchChatroomInfo:roomId completion:^(NSError *error, NIMChatroom *chatroom) {
        if(error){
            NSDictionary *dic = @{@"error":@(error.code)};
            [func executeWithArguments:ACArgsPack(@(0),dic)];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbGetChatRoomInfo" parameter:@{@"error":@(error.code),@"data":@""}];
        }
        else{
            NSDictionary *dic = @{@"error":@"",@"data":[self.uexNIMMgr analyzeWithNIMChatroom:chatroom]};
            [func executeWithArguments:ACArgsPack(@(0),@{@"data":[self.uexNIMMgr analyzeWithNIMChatroom:chatroom]})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbGetChatRoomInfo" parameter:dic];
        }
    }];
}
-(void)getChatRoomMembers:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    NSInteger limit=10;
    if([info objectForKey:@"limit"]){
        limit=[[info objectForKey:@"limit"] integerValue]?:10;
    }
    
    NIMChatroomFetchMemberType type=NIMChatroomFetchMemberTypeRegular;
    if([info objectForKey:@"type"] && [[info objectForKey:@"type"] integerValue]==1){
        type=NIMChatroomFetchMemberTypeTemp;
    }
    else if ([info objectForKey:@"type"] && [[info objectForKey:@"type"] integerValue]==2){
        type=NIMChatroomFetchMemberTypeRegularOnline;
    }
    
    NIMChatroomMemberRequest *request=[NIMChatroomMemberRequest alloc];
    
//    NIMChatroomMember *lastMember=[[NIMChatroomMember alloc] init];
//    lastMember.userId=@"appcanuser1";
//    lastMember.enterTimeInterval=111111;
    
    NIMChatroomMember *lastMember=nil;
    request.roomId=roomId;
    request.limit=limit;
    request.type=type;
    request.lastMember=lastMember;
    if([info objectForKey:@"userId"] && ![[info objectForKey:@"userId"] isEqual:@""]){
        NSArray *userIds=[[NSArray alloc]initWithObjects:[info objectForKey:@"userId"], nil];
        NIMChatroomMembersByIdsRequest *request2=[[NIMChatroomMembersByIdsRequest alloc]init];
        request2.roomId=roomId;
        request2.userIds=userIds;
        [self.uexNIMMgr.SDK.chatroomManager fetchChatroomMembersByIds:request2 completion:^(NSError *error, NSArray *members) {
            
            if(!error && members.count>0){
                request.lastMember=members[0];
            }
            [self getChatRoomMembersFromMember:request Function:func];
        }];
    }
    else{
        [self getChatRoomMembersFromMember:request Function:func];
    }
    
}
-(void)getChatRoomMembersFromMember:(NIMChatroomMemberRequest *)request Function:(ACJSFunctionRef*)func{
    
    [self.uexNIMMgr.SDK.chatroomManager fetchChatroomMembers:request completion:^(NSError *error, NSArray *members) {
        NSMutableArray *memberArr=[NSMutableArray array];
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if(error){
            [result setValue:@(error.code) forKey:@"error"];
            [result setValue:@"" forKey:@"data"];
            [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
        }
        else{
            for (NIMChatroomMember *member in members) {
                [memberArr addObject:[self.uexNIMMgr analyzeWithNIMChatroomMember:member]];
            }
            [result setValue:@"" forKey:@"error"];
            [result setValue:memberArr forKey:@"data"];
            [func executeWithArguments:ACArgsPack(@(0),@{@"data":memberArr})];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbGetChatRoomMembers" parameter:result];
    }];
}

-(void)getChatRoomMembersByIds:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    NSArray *userIds=nil;
    if([info objectForKey:@"userIds"]){
        if([[info objectForKey:@"userIds"] isKindOfClass:[NSArray class]]){
            userIds=[info objectForKey:@"userIds"];
        }
        else{
            userIds=[[info objectForKey:@"userIds"] ac_JSONValue];
        }
    }
    
    NIMChatroomMembersByIdsRequest *request=[NIMChatroomMembersByIdsRequest alloc];
    request.roomId=roomId;
    request.userIds=userIds;
    [self.uexNIMMgr.SDK.chatroomManager fetchChatroomMembersByIds:request completion:^(NSError *error, NSArray *members) {
        NSMutableArray *memberArr=[NSMutableArray array];
        NSMutableDictionary *result=[NSMutableDictionary dictionary];
        if(error){
            [result setValue:@(error.code) forKey:@"error"];
            [result setValue:@"" forKey:@"data"];
             [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
        }
        else{
            for (NIMChatroomMember *member in members) {
                [memberArr addObject:[self.uexNIMMgr analyzeWithNIMChatroomMember:member]];
            }
            [result setValue:@"" forKey:@"error"];
            [result setValue:memberArr forKey:@"data"];
            [func executeWithArguments:ACArgsPack(@(0),@{@"data":memberArr})];
        }
        [self.uexNIMMgr callBackJsonWithFunction:@"cbGetChatRoomMembers" parameter:result];
    }];
    
}
-(void)addUserToBlackList:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    NSString *userId=[info objectForKey:@"userId"];
    bool enable=YES;
    if([info objectForKey:@"isAdd"] && [[info objectForKey:@"isAdd"] boolValue]==NO){
        enable=NO;
    }
    
    NIMChatroomMemberUpdateRequest *request=[NIMChatroomMemberUpdateRequest alloc];
    request.roomId=roomId;
    request.userId=userId;
    request.enable=enable;
    
    [self.uexNIMMgr.SDK.chatroomManager updateMemberBlack:request completion:^(NSError *error) {
        if (error) {
             [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
             [self.uexNIMMgr callBackJsonWithFunction:@"cbAddUserToBlackList" parameter:@{@"error":@(error.code)}];
        }else{
            [func executeWithArguments:ACArgsPack(@(0),@{@"error":@""})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbAddUserToBlackList" parameter:@{@"error":@""}];
        }
    }];
}
-(void)muteUser:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    NSString *userId=[info objectForKey:@"userId"];
    bool enable=YES;
    if([info objectForKey:@"isMute"] && [[info objectForKey:@"isMute"] boolValue]==NO){
        enable=NO;
    }
    
    NIMChatroomMemberUpdateRequest *request=[NIMChatroomMemberUpdateRequest alloc];
    request.roomId=roomId;
    request.userId=userId;
    request.enable=enable;
    
    [self.uexNIMMgr.SDK.chatroomManager updateMemberMute:request completion:^(NSError *error) {
        if (error) {
            [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbMuteUser" parameter:@{@"error":@(error.code)}];
        }else{
            [func executeWithArguments:ACArgsPack(@(0),@{@"error":@""})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbMuteUser" parameter:@{@"error":@""}];
        }
    }];
}
-(void)setAdmin:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    NSString *userId=[info objectForKey:@"userId"];
    bool enable=YES;
    if([info objectForKey:@"isAdmin"] && [[info objectForKey:@"isAdmin"] boolValue]==NO){
        enable=NO;
    }
    
    NIMChatroomMemberUpdateRequest *request=[NIMChatroomMemberUpdateRequest alloc];
    request.roomId=roomId;
    request.userId=userId;
    request.enable=enable;
    
    [self.uexNIMMgr.SDK.chatroomManager markMemberManager:request completion:^(NSError *error) {
        if (error) {
            [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbSetAdmin" parameter:@{@"error":@(error.code)}];
        }else{
            [func executeWithArguments:ACArgsPack(@(0),@{@"error":@""})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbSetAdmin" parameter:@{@"error":@""}];
        }
    }];
}
-(void)setNormal:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
     ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    NSString *userId=[info objectForKey:@"userId"];
    bool enable=YES;
    if([info objectForKey:@"isNormal"] && [[info objectForKey:@"isNormal"] boolValue]==NO){
        enable=NO;
    }
    
    NIMChatroomMemberUpdateRequest *request=[NIMChatroomMemberUpdateRequest alloc];
    request.roomId=roomId;
    request.userId=userId;
    request.enable=enable;
    
    [self.uexNIMMgr.SDK.chatroomManager markNormalMember:request completion:^(NSError *error) {
        if (error) {
            [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbSetNormal" parameter:@{@"error":@(error.code)}];
        }else{
            [func executeWithArguments:ACArgsPack(@(0),@{@"error":@""})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbSetNormal" parameter:@{@"error":@""}];
        }
    }];
}
-(void)kickMemberFromChatRoom:(NSMutableArray *)inArguments{
    if(inArguments.count<1){
        return;
    }
    //id info=[inArguments[0] JSONValue];
    ACArgsUnpack(NSDictionary *info, ACJSFunctionRef*func) = inArguments;
    NSString *roomId=[info objectForKey:@"roomId"];
    NSString *userId=[info objectForKey:@"userId"];
    
    NIMChatroomMemberKickRequest *request=[NIMChatroomMemberKickRequest alloc];
    request.roomId=roomId;
    request.userId=userId;
    
    [self.uexNIMMgr.SDK.chatroomManager kickMember:request completion:^(NSError *error) {
        if (error) {
            [func executeWithArguments:ACArgsPack(@(1),@{@"error":@(error.code)})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbKickMemberFromChatRoom" parameter:@{@"error":@(error.code)}];
        }else{
            [func executeWithArguments:ACArgsPack(@(0),@{@"error":@""})];
            [self.uexNIMMgr callBackJsonWithFunction:@"cbKickMemberFromChatRoom" parameter:@{@"error":@""}];
        }
    }];
}
@end
