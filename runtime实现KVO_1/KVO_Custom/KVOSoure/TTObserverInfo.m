//
//  TTObserverInfo.m
//  KVO_Custom
//
//  Created by sunzongtang on 2017/12/14.
//  Copyright © 2017年 szt. All rights reserved.
//

#import "TTObserverInfo.h"

@interface TTObserverInfo ()

@property (nonatomic, weak) id observer;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, copy) TTKVOCallBlockType callBlock;

@end
@implementation TTObserverInfo

+ (instancetype)observerInfo:(id)observer keyPath:(NSString *)keyPath callBlock:(TTKVOCallBlockType)callBlock {
    TTObserverInfo *observerInfo = [TTObserverInfo new];
    observerInfo.observer  = observer;
    observerInfo.keyPath   = keyPath;
    observerInfo.callBlock = callBlock;
    return observerInfo;
}

@end
