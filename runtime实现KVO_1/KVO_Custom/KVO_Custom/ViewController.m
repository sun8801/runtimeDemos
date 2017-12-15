//
//  ViewController.m
//  KVO_Custom
//
//  Created by sunzongtang on 2017/12/14.
//  Copyright © 2017年 szt. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+TTKVO.h"

#import "TestObject.h"
#import "NextViewController.h"

@interface ViewController ()

@property (nonatomic, strong) TestObject *tObj;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self.view tt_addObserver:self forKeyPath:@"backgroundColor" callBlock:^(NSString *keyPath, id oldValue, id newValue) {
        NSLog(@">>>KVO:%@",newValue);
    }];
    
    self.tObj = [TestObject new];
    [self.tObj tt_addObserver:self forKeyPath:@"age" callBlock:^(NSString *keyPath, id oldValue, id newValue) {
        NSLog(@"*****改变了年龄--%@》》》》》》",newValue);
    }];
}

- (IBAction)changeBtnAction:(UIButton *)sender {

    self.view.backgroundColor = [UIColor colorWithRed:(arc4random()%256)/255.0 green:(arc4random()%256)/255.0 blue:(arc4random()%256)/255.0 alpha:1];
    
    self.tObj.age = 15.5;
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    [(NextViewController *)segue.destinationViewController setTObj:self.tObj];
}

@end
