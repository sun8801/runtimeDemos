//
//  NSObject+TTKVO.h
//  KVO_Custom
//
//  Created by sunzongtang on 2017/12/14.
//  Copyright © 2017年 szt. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^TTKVOCallBlock)(NSString *keyPath, id oldValue, id newValue);

@interface NSObject (TTKVO)

/**
 添加KVO 当observer被销毁了后，监听对象改变时会自动销毁，不会自己调用block

 @param observer <#observer description#>
 @param keyPath <#keyPath description#>
 @param block <#block description#>
 */
- (void)tt_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath callBlock:(TTKVOCallBlock )block;

/**
 移除KVO

 @param observer <#observer description#>
 @param keyPath <#keyPath description#>
 */
- (void)tt_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

@end
