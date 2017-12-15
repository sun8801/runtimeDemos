//
//  NSObject+TTKVO.m
//  KVO_Custom
//
//  Created by sunzongtang on 2017/12/14.
//  Copyright © 2017年 szt. All rights reserved.
//

#import "NSObject+TTKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

//
const void *TTObserversKey = &TTObserversKey;

//自定义KVO类的前缀
static NSString *const TTKVONotifyingPrefix = @"TTKVONotifying_";

#define kTTKVOStringIsEmpty(str) (([str isKindOfClass:[NSNull class]] || str == nil || [str length] < 1) ? YES : NO )
/** 字符串只有空格和换行 */
#define kTTKVOStringOnlyIsWhitespaceAndNewline(str) (kTTKVOStringIsEmpty([(str) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]))

static dispatch_queue_t TTKVOObserverQueue(void) {
    static dispatch_queue_t TTKVOQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        TTKVOQueue = dispatch_queue_create("com.ttkvo.observerinfo.queue", DISPATCH_QUEUE_SERIAL);
    });
    return TTKVOQueue;
}

/** keyPath转成Setter方法字符串 */
static NSString *TT_setterFromKeyPath(NSString *keyPath) {
    NSString *firstChar = [[keyPath substringToIndex:1] uppercaseString];
    return [NSString stringWithFormat:@"set%@%@:",firstChar,[keyPath substringFromIndex:1]];
}
/** 获取getter方法名 */
static NSString *TT_getterFromSetter(NSString *setterName) {
    if ([setterName hasPrefix:@"set"] && [setterName hasSuffix:@":"]) {
        NSString *getter = [setterName substringWithRange:NSMakeRange(3, setterName.length -4)];
        NSString *firstChar = [[getter substringToIndex:1] lowercaseString];
        return [NSString stringWithFormat:@"%@%@",firstChar, [getter substringFromIndex:1]];
    }
    return nil;
}
/** 修改class方法 */
static Class TT_KVOClass(id self, SEL _cmd) {
    Class KVOCls = object_getClass(self);
    Class superCls = class_getSuperclass(KVOCls);
    return superCls;
}

/** 注册KVO 类 */
static Class TT_registerKVOClassForOriginalClassName(NSString *oClsName) {
    NSString *KVOClsName = [TTKVONotifyingPrefix stringByAppendingString:oClsName];
    Class KVOCls = NSClassFromString(KVOClsName);
    if (KVOCls) { //已经注册过
        return KVOCls;
    }
    //创建KVO类
    Class originalCls =  NSClassFromString(oClsName);
    KVOCls = objc_allocateClassPair(originalCls, KVOClsName.UTF8String, 0);
    
    //修改KVOCls 的class方法实现, 隐瞒这个kvo_class 表面看起来没有改变类
    Method clsMethod = class_getInstanceMethod(KVOCls, @selector(class));
    const char *clsMType = method_getTypeEncoding(clsMethod);
    class_addMethod(KVOCls, @selector(class), (IMP)TT_KVOClass, clsMType);
    
    //注册KVO Cls
    objc_registerClassPair(KVOCls);
    
    return KVOCls;
}

//基本数据类型 int  float char
// > long double

/** 实现KVO setter 方法 */
//对象类型
static void TT_KVOSetterObj(id self, SEL _cmd, id newValue) {
    
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = TT_getterFromSetter(setterName);
    if (!getterName) {
        return;
    }
    id oldValue = [self valueForKey:getterName];
    
    struct objc_super superCls = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    void(*objc_msgSendSuperCast)(void *, SEL, id) = (void (*)(void *, SEL, id))objc_msgSendSuper;
    objc_msgSendSuperCast(&superCls, _cmd, newValue);
    
    NSMutableArray <TTObserverInfo *> *observerInfos = objc_getAssociatedObject(self, TTObserversKey);
    if (observerInfos) {
        [observerInfos enumerateObjectsUsingBlock:^(TTObserverInfo * _Nonnull observerInfoObj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([observerInfoObj.keyPath isEqualToString:getterName]) {
                if (observerInfoObj.observer && observerInfoObj.callBlock) {
                    observerInfoObj.callBlock(getterName, oldValue, newValue);
                }else {
                    //移除监听对象
                    [observerInfos removeObject:observerInfoObj];
                }
            }
        }];
    }
}
//整形
static void TT_KVOSetterInt(id self, SEL _cmd, long tint)  {
    TT_KVOSetterObj(self, _cmd, @(tint));
}
//浮点型
static void TT_KVOSetterFloat(id self, SEL _cmd, double tfloat)  {
    TT_KVOSetterObj(self, _cmd, @(tfloat));
}
/** 获取value的类型 */
static char TT_KVOSetterVauleEncodeType(const char *encodeTypes) {
    //关于typeEncoding http://www.jianshu.com/p/f4129b5194c0
    //@encode(int) 获取类型
    //判断 set:(type) 值的类型
    // 'd' 'f' > double float
    // '@' > id ...
    // :
    if (encodeTypes == NULL) {
        return '@';
    }
    int i = 0;
    char c_char = encodeTypes[i];
    while (c_char != '\0') {
        if (c_char == ':') {
            encodeTypes = &encodeTypes[i];
            break;
        }
        i++;
        c_char = encodeTypes[i];
    }
    
    i = 0;
    c_char = encodeTypes[i];
    while (c_char != '\0') {
        if (c_char == 'd' || c_char == 'f') {
            return 'f';
        }
        if (c_char == '@') {
            return '@';
        }
        i++;
        c_char = encodeTypes[i];
    }
    
    return 'i';
}

@implementation NSObject (TTKVO)

- (void)tt_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath callBlock:(TTKVOCallBlockType)block {
    if (!keyPath || kTTKVOStringOnlyIsWhitespaceAndNewline(keyPath) || !block) {
        return;
    }
    
    // 1. 检查对象的类有没有相应的 setter 方法。如果没有抛出异常
    NSString *keyPathSetter = TT_setterFromKeyPath(keyPath);
    SEL keyPathSetterSel = NSSelectorFromString(keyPathSetter);
    //判断有无setter方法
    Method setterMethod = class_getInstanceMethod([self class], keyPathSetterSel);
    if (!setterMethod) {
        NSAssert(NO, ([NSString stringWithFormat:@"****当前类没有《%@》属性****",keyPath]));
        return;
    }
    
    // 2. 检查对象 isa 指向的类是不是一个 KVO 类。如果不是，新建一个继承原来类的子类，并把 isa 指向这个新建的子类
    Class cls = object_getClass(self);
    NSString *clsName = NSStringFromClass(cls);
    if (![clsName hasPrefix:TTKVONotifyingPrefix]) {
        cls = TT_registerKVOClassForOriginalClassName(clsName);
        object_setClass(self, cls);
    }
    
    //到这里，object的类已不是原类了, 而是KVO新建的类
    // 3 .KVO class 实现setter方法
    //TT_KVOSetter函数需区分对象类型和基本数据类型，
    const char *types = method_getTypeEncoding(setterMethod);
    char valueType = TT_KVOSetterVauleEncodeType(types);
    if (valueType == 'i') {
        class_addMethod(cls, keyPathSetterSel, (IMP)TT_KVOSetterInt, types);
    }else if (valueType == 'f') {
        class_addMethod(cls, keyPathSetterSel, (IMP)TT_KVOSetterFloat, types);
    }else {
        class_addMethod(cls, keyPathSetterSel, (IMP)TT_KVOSetterObj, types);
    }
    
    //4 .把观察者添加到列表中
    __block NSMutableArray *observerInfos;
    dispatch_sync(TTKVOObserverQueue(), ^{
        observerInfos = objc_getAssociatedObject(self, TTObserversKey);
        if (!observerInfos) {
            observerInfos = [NSMutableArray array];
            objc_setAssociatedObject(self, TTObserversKey, observerInfos, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    });
    TTObserverInfo *observerInfo = [TTObserverInfo observerInfo:observer keyPath:keyPath callBlock:block];
    [observerInfos addObject:observerInfo];
}

- (void)tt_removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    NSMutableArray <TTObserverInfo *> *observerInfos = objc_getAssociatedObject(self, TTObserversKey);
    if (observerInfos) {
        [observerInfos enumerateObjectsUsingBlock:^(TTObserverInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.observer == observer && [obj.keyPath isEqualToString:keyPath]) {
                [observerInfos removeObject:obj];
            }
        }];
    }
}

@end
