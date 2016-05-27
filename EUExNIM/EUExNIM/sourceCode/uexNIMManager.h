//
//  uexNIMManager.h
//  EUExNIM
//
//  Created by 黄锦 on 16/1/8.
//  Copyright © 2016年 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSON.h"
#import "EUtility.h"
#import "EUExNIM.h"
#import "NTESGLView.h"

@interface uexNIMManager : NSObject<NIMLoginManagerDelegate,NIMMediaManagerDelgate,NIMNetCallManagerDelegate,NIMSystemNotificationManagerDelegate,NIMTeamManagerDelegate,NIMUserManagerDelegate,NIMConversationManagerDelegate,NIMChatManagerDelegate,NIMChatroomManagerDelegate>
@property (nonatomic ,weak) NIMSDK *SDK;
@property (nonatomic,strong) dispatch_queue_t callBackDispatchQueue;
@property (nonatomic,weak) NIMMessage *message;
@property (nonatomic,strong) CALayer *localVideoLayer;
@property (nonatomic,strong) UIView *localView;
@property (nonatomic,assign) BOOL oppositeCloseVideo;
@property (nonatomic, strong) NTESGLView *remoteGLView;
@property (nonatomic, strong) UIImageView *remoteView;


+ (instancetype)sharedInstance;
-(void) registerApp:(NSString *)appKey apnsCertName:(NSString *)apnsCertName;
-(void)callBackJsonWithFunction:(NSString *)functionName parameter:(id)obj;
-(NSMutableDictionary*)analyzeWithNIMMessage:(NIMMessage *)message;
-(NSMutableDictionary*)analyzeWithNIMRecentSession:(NIMRecentSession *)recentSession;
-(NSMutableDictionary*)analyzeWithNIMTeam:(NIMTeam *)team;
-(NSMutableDictionary*)analyzeWithNIMTeamMember:(NIMTeamMember *)member;
-(NSMutableDictionary*)analyzeWithSystemNotification:(NIMSystemNotification *)notification;
-(NSMutableDictionary*)analyzeWithNIMUser:(NIMUser *)userl;
-(NSMutableDictionary*)analyzeWithNIMChatroom:(NIMChatroom *)room;
-(NSMutableDictionary*)analyzeWithNIMChatroomMember:(NIMChatroomMember *)member;

-(void)playAudio:(NSString *)filePath;

@end
