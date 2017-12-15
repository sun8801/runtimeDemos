//
//  TTObserverInfo.h
//  KVO_Custom
//
//  Created by sunzongtang on 2017/12/14.
//  Copyright © 2017年 szt. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^TTKVOCallBlockType)(NSString *keyPath, id oldValue, id newValue);

@interface TTObserverInfo : NSObject

+ (instancetype)observerInfo:(id)observer keyPath:(NSString *)keyPath callBlock:(TTKVOCallBlockType) callBlock;

@property (nonatomic, weak, readonly) id observer;
@property (nonatomic, copy, readonly) NSString *keyPath;
@property (nonatomic, copy, readonly) TTKVOCallBlockType callBlock;

@end
