//
//  UIViewController+Hook.m
//  HookDylib
//
//  Created by xindong on 17/7/19.
//  Copyright © 2017年 xindong. All rights reserved.
//

#import "UIViewController+Hook.h"
#import <objc/runtime.h>

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

typedef void(^AlertViewActionBlock)(NSUInteger actionIndex);

@interface UIViewController (Alert)

- (UIAlertController *)showAlertWithTitle:(NSString * _Nullable)title
                                  message:(NSString * _Nullable)message
                             actionTitles:(NSArray<NSString *> *)actionTitles
                                   action:(AlertViewActionBlock)actionBlock;

@end

@implementation UIViewController (Alert)

- (UIAlertController *)showAlertWithTitle:(NSString *)title
                                  message:(NSString *)message
                             actionTitles:(NSArray<NSString *> *)actionTitles
                                   action:(AlertViewActionBlock)actionBlock {
    NSAssert(actionTitles.count != 0, @"The actionTitles cann't be nil.");
    if (actionTitles.count == 0) return nil;
    
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [self xd_setupAlertController:alertVC titles:actionTitles action:actionBlock];
    [self presentViewController:alertVC animated:YES completion:nil];
    return alertVC;
}

- (void)xd_setupAlertController:(UIAlertController *)alertVC titles:(NSArray<NSString *> *)actionTitles action:(AlertViewActionBlock)actionBlock {
    for (NSUInteger i = 0; i < actionTitles.count; i++) {
        NSString *text = [actionTitles objectAtIndex:i];
        UIAlertAction *action = [UIAlertAction actionWithTitle:text style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (actionBlock) actionBlock(i);
        }];
        [alertVC addAction:action];
    }
}

@end

#pragma mark ---------------- 华丽的分割线 ----------------

static NSInteger const kTextViewIdentifier = 20170719;

@implementation UIViewController (Hook)

- (void)xd_viewDidLoad {
    [self xd_viewDidLoad];
    if ([self isInvalidateViewController]) {
        NSLog(@"invalidate viewController: %@", NSStringFromClass([self class]));
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showAlertWithTitle:@"提示" message:@"是否要将当前UIViewController的类名以及所有实例变量展示出来？" actionTitles:@[@"不要", @"要要"] action:^(NSUInteger actionIndex) {
            if (actionIndex == 1) {
                [self xd_setupPrintEnvironment];
            }
        }];
    });
}

- (BOOL)isInvalidateViewController {
    BOOL invalidateVC1 = [self isKindOfClass:[UINavigationController class]];
    BOOL invalidateVC2 = [self isKindOfClass:[UITabBarController class]];
    BOOL invalidateVC3 = [self isKindOfClass:[UIInputViewController class]];
    BOOL invalidateVC4 = [self isKindOfClass:NSClassFromString(@"UIInputWindowController")];
    BOOL invalidateVC5 = [self isKindOfClass:[UIAlertController class]];
    BOOL invalidateVC6 = [self isKindOfClass:NSClassFromString(@"_UIAlertControllerTextFieldViewController")];
    
    BOOL invalidateViewController = invalidateVC1 || invalidateVC2 || invalidateVC3 || invalidateVC4 || invalidateVC5 || invalidateVC6;
    
    return invalidateViewController;
}

- (void)xd_setupPrintEnvironment {
    UITextView *textView = [UITextView new];
    textView.frame = (CGRect){0, 64, SCREEN_WIDTH, SCREEN_HEIGHT - 128};
    textView.editable = NO;
    textView.backgroundColor = [UIColor yellowColor];
    textView.tag = kTextViewIdentifier;
    textView.text = [self xd_printCurrentViewControllerNameAndIvar];
    [[UIApplication sharedApplication].keyWindow addSubview:textView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(xd_clickedToDismissTextView:)];
    [textView addGestureRecognizer:tap];
}

- (NSString *)xd_printCurrentViewControllerNameAndIvar {
    NSString *currentClassName = [NSString stringWithFormat:@" ViewControllerName: %@\n", NSStringFromClass([self class])];
    NSMutableString *text = [currentClassName mutableCopy];
    
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList([self class], &outCount);
    for (int i = 0; i < outCount; i++) {
        Ivar _ivar = ivars[i];
        const char *_ivarCN = ivar_getName(_ivar);
        const char *_ivarType = ivar_getTypeEncoding(_ivar);
        NSString *ivarName = [NSString stringWithUTF8String:_ivarCN];
        NSString *ivarType = [NSString stringWithUTF8String:_ivarType];
        [text appendFormat:@"%@", [NSString stringWithFormat:@"\n ivarName: %@  type: %@", ivarName, ivarType]];
    }
    return text;
}

- (void)xd_clickedToDismissTextView:(UITapGestureRecognizer *)tap {
    [[UIApplication sharedApplication].keyWindow.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[UITextView class]] && obj.tag == kTextViewIdentifier) {
            [obj removeFromSuperview];
        }
    }];
}


#pragma mark - Method Swizzling

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self xd_exchangeOriginSelector:@selector(viewDidLoad) newSelector:@selector(xd_viewDidLoad)];
    });
}

+ (void)xd_exchangeOriginSelector:(SEL)selectorOrigin newSelector:(SEL)selectorNew {
    Class _Class = [self class];
    
    Method methodOrigin = class_getInstanceMethod(_Class, selectorOrigin);
    Method methodNew = class_getInstanceMethod(_Class, selectorNew);
    
    IMP impOrigin = method_getImplementation(methodOrigin);
    IMP impNew = method_getImplementation(methodNew);
    
    BOOL isAdd = class_addMethod(_Class, selectorOrigin, impNew, method_getTypeEncoding(methodNew));
    if (isAdd) {
        class_addMethod(_Class, selectorNew, impOrigin, method_getTypeEncoding(methodOrigin));
    } else {
        method_exchangeImplementations(methodOrigin, methodNew);
    }
}

@end
