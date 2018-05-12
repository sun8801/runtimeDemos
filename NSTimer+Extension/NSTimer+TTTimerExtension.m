//
//  NSTimer+TTTimerExtension.m
//
//  Created by sun-zt on 2018/5/8.
//  Copyright © 2018年 MOMO. All rights reserved.
//

#import "NSTimer+TTTimerExtension.h"
#import <objc/runtime.h>

static inline void TT_swizzleClassSelector(Class class, SEL originalSelector, SEL newSelector) {
    
    Method origMethod     = class_getClassMethod(class, originalSelector);
    Method swizzledMethod = class_getClassMethod(class, newSelector);
    Class metaClass       = object_getClass(class);
    
    BOOL isAdd = class_addMethod(metaClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if(isAdd) {
        class_replaceMethod(metaClass, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, swizzledMethod);
    }
}

//static inline void TT_swizzleInstanceSelector(Class class, SEL originalSelector, SEL newSelector) {
//    Method origMethod     = class_getInstanceMethod(class, originalSelector);
//    Method swizzledMethod = class_getInstanceMethod(class, newSelector);
//
//    BOOL isAdd = class_addMethod(metaClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
//    if(isAdd) {
//        class_replaceMethod(metaClass, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
//    } else {
//        method_exchangeImplementations(origMethod, swizzledMethod);
//    }
//}

//typedef void(^TTTimerBlock)(NSTimer *timer);

#pragma mark - TTTimerWeakTargetObj 执行timer调用
@interface TTTimerWeakTargetObj : NSObject

+ (instancetype)timerWeakObjWithTarget:(id)target selecor:(SEL)aSelecor;
- (void)loopTimer:(NSTimer *)timer;

- (instancetype)init NS_UNAVAILABLE;

@end
@implementation TTTimerWeakTargetObj
{
    __weak id _target;
    SEL _selector;
}

+ (instancetype)timerWeakObjWithTarget:(id)target selecor:(SEL)aSelecor {
    TTTimerWeakTargetObj *timerWeakObj = [TTTimerWeakTargetObj new];
    timerWeakObj->_target = target;
    timerWeakObj->_selector = aSelecor;
    return timerWeakObj;
}

- (void)loopTimer:(NSTimer *)timer {
    if (!_target) {
        [timer invalidate];
        return;
    }
    if ([_target respondsToSelector:_selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_target performSelector:_selector withObject:timer];
#pragma clang diagnostic pop
//        NSMethodSignature *methodSignature = [_target methodSignatureForSelector:_selector];
//        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
//        if (methodSignature.numberOfArguments > 2) [invocation setArgument:&timer atIndex:2];
//        invocation.selector = _selector;
//        [invocation invokeWithTarget:_target];
    } else {
        [_target doesNotRecognizeSelector:_selector];
    }
}

- (void)dealloc {
//    NSLog(@">>>%@>>>>dealloc>>>>",self.class);
}

@end

#pragma mark - TTTimerWeakLifecycleObj 用于管理timer的生命周期
//添加到target
@interface TTTimerWeakLifecycleObj : NSObject

@property (nonatomic, weak) NSTimer *timer;

@end
@implementation TTTimerWeakLifecycleObj

- (void)dealloc {
//    NSLog(@">>>%@>>>>dealloc>>>>",self.class);
    if (!self.timer.isValid) return;
    [self.timer invalidate];
    self.timer = nil;

}
@end

@implementation NSTimer (TTTimerExtension)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleTimerSelectors];
    });
}

+ (void)swizzleTimerSelectors {

    /**
     + (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti invocation:(NSInvocation *)invocation repeats:(BOOL)yesOrNo;
     + (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti invocation:(NSInvocation *)invocation repeats:(BOOL)yesOrNo;
     
     + (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo;
     + (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo;
     
     + (NSTimer *)timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;
     + (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;
     
     - (instancetype)initWithFireDate:(NSDate *)date interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;
     - (instancetype)initWithFireDate:(NSDate *)date interval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(nullable id)ui repeats:(BOOL)rep;
     */
    
    //NSInvocation
    TT_swizzleClassSelector(self,
                            @selector(timerWithTimeInterval:invocation:repeats:),
                            @selector(TT_timerWithTimeInterval:invocation:repeats:));
    TT_swizzleClassSelector(self,
                            @selector(scheduledTimerWithTimeInterval:invocation:repeats:),
                            @selector(TT_scheduledTimerWithTimeInterval:invocation:repeats:));
    
    //selector
    TT_swizzleClassSelector(self,
                            @selector(timerWithTimeInterval:target:selector:userInfo:repeats:),
                            @selector(TT_timerWithTimeInterval:target:selector:userInfo:repeats:));
    TT_swizzleClassSelector(self,
                            @selector(scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:),
                            @selector(TT_scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:));
    
    //block
    
    //init
    
}

#pragma mark -NSInvocation
+ (NSTimer *)TT_timerWithTimeInterval:(NSTimeInterval)ti invocation:(NSInvocation *)invocation repeats:(BOOL)yesOrNo {
    TTTimerWeakTargetObj *timerWeakObj = [TTTimerWeakTargetObj timerWeakObjWithTarget:invocation.target selecor:invocation.selector];
    NSMethodSignature *tMethodSignature = [timerWeakObj methodSignatureForSelector:@selector(loopTimer:)];
    NSInvocation *tInvocation = [NSInvocation invocationWithMethodSignature:tMethodSignature];
    tInvocation.target = timerWeakObj;
    tInvocation.selector = @selector(loopTimer:);
    NSTimer *timer = [self TT_timerWithTimeInterval:ti invocation:tInvocation repeats:yesOrNo];
    TTTimerWeakLifecycleObj *timerWeakLifecycleObj = [TTTimerWeakLifecycleObj new];
    timerWeakLifecycleObj.timer = timer;
    objc_setAssociatedObject(invocation.target, _cmd, timerWeakLifecycleObj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return timer;
}
+ (NSTimer *)TT_scheduledTimerWithTimeInterval:(NSTimeInterval)ti invocation:(NSInvocation *)invocation repeats:(BOOL)yesOrNo {
    TTTimerWeakTargetObj *timerWeakObj = [TTTimerWeakTargetObj timerWeakObjWithTarget:invocation.target selecor:invocation.selector];
    NSMethodSignature *tMethodSignature = [timerWeakObj methodSignatureForSelector:@selector(loopTimer:)];
    NSInvocation *tInvocation = [NSInvocation invocationWithMethodSignature:tMethodSignature];
    tInvocation.target = timerWeakObj;
    tInvocation.selector = @selector(loopTimer:);
    NSTimer *timer = [self TT_scheduledTimerWithTimeInterval:ti invocation:tInvocation repeats:yesOrNo];
    TTTimerWeakLifecycleObj *timerWeakLifecycleObj = [TTTimerWeakLifecycleObj new];
    timerWeakLifecycleObj.timer = timer;
    objc_setAssociatedObject(invocation.target, _cmd, timerWeakLifecycleObj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return timer;
}

#pragma mark - selector
+ (NSTimer *)TT_timerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo {
    TTTimerWeakTargetObj *timerWeakObj = [TTTimerWeakTargetObj timerWeakObjWithTarget:aTarget selecor:aSelector];
    NSTimer *timer = [self TT_timerWithTimeInterval:ti target:timerWeakObj selector:@selector(loopTimer:) userInfo:userInfo repeats:yesOrNo];
    TTTimerWeakLifecycleObj *timerWeakLifecycleObj = [TTTimerWeakLifecycleObj new];
    timerWeakLifecycleObj.timer = timer;
    objc_setAssociatedObject(aTarget, _cmd, timerWeakLifecycleObj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return timer;
}
+ (NSTimer *)TT_scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo {
    TTTimerWeakTargetObj *timerWeakObj = [TTTimerWeakTargetObj timerWeakObjWithTarget:aTarget selecor:aSelector];
    NSTimer *timer = [self TT_scheduledTimerWithTimeInterval:ti target:timerWeakObj selector:@selector(loopTimer:) userInfo:userInfo repeats:yesOrNo];
    TTTimerWeakLifecycleObj *timerWeakLifecycleObj = [TTTimerWeakLifecycleObj new];
    timerWeakLifecycleObj.timer = timer;
    objc_setAssociatedObject(aTarget, _cmd, timerWeakLifecycleObj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return timer;
}

#pragma mark - block

@end

