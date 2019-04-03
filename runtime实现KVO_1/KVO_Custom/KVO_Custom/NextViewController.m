//
//  NextViewController.m
//  KVO_Custom
//
//  Created by sunzongtang on 2017/12/14.
//  Copyright © 2017年 szt. All rights reserved.
//

#import "NextViewController.h"
#import "NSObject+TTKVO.h"

#import "NSTimer+TTTimerExtension.h"

@interface NextViewController ()

@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, weak) TestObject *objttt;

@end

static TestObject *objtt = nil;

@implementation NextViewController

- (void)dealloc {
    NSLog(@"****dealloc****%@****",self.class);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self.view tt_addObserver:self forKeyPath:@"backgroundColor" callBlock:^(NSString *keyPath, id oldValue, id newValue) {
        NSLog(@">Next>>KVO:%@",newValue);
    }];
    
    [self.tObj tt_addObserver:self forKeyPath:@"age" callBlock:^(NSString *keyPath, id oldValue, id newValue) {
        NSLog(@"**next***改变了年龄--%@》》》》》》",newValue);
    }];
    
//    NSTimer *timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
//
//    }];
    NSTimer *timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(repeateTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
    
    objtt = TestObject.new;
    self.objttt = objtt;
    
}

- (IBAction)changeBtnAction:(UIButton *)sender {
    self.view.backgroundColor = [UIColor colorWithRed:(arc4random()%256)/255.0 green:(arc4random()%256)/255.0 blue:(arc4random()%256)/255.0 alpha:1];
    
    self.tObj.age = 33.3f;
}

- (void)repeateTimer:(NSTimer *)timer {
    NSLog(@"%@",timer);
}

@end
