//
//  UIViewController+LoadTimeProfiler.m
//  VCLoadTimeProfiler
//
//  Created by Brooks on 2018/8/16.
//

#import "UIViewController+LoadTimeProfiler.h"
#import <objc/runtime.h>

#define VCP_LOG_ENABLE 1

#ifdef VCP_LOG_ENABLE
#define VCLog(...) NSLog(__VA_ARGS__)
#else
#define VCLog(...)
#endif

static char const kAssociatedRemoverKey;

static NSString *const kUniqueFakeKeyPath = @"useless_key_path";




#pragma mark -

@implementation Fake_KVO_Observer

+ (instancetype)shared {
    static id sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

@end


#pragma mark -

@implementation Fake_KVO_Remover

- (void)dealloc {
    VCLog(@"dealloc: %@", _target);
    [_target removeObserver:[Fake_KVO_Observer shared] forKeyPath:_keyPath];
    _target = nil;
}

@end


#pragma mark -

@implementation UIViewController (LoadTimeProfiler)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [UIViewController class];
        [self swizzleMethodInClass:class originalMethod:@selector(initWithNibName:bundle:) swizzledSelector:@selector(pmy_initWithNibName:bundle:)];
        [self swizzleMethodInClass:class originalMethod:@selector(initWithCoder:) swizzledSelector:@selector(pmy_initWithCoder:)];
    });
}

- (instancetype)pmy_initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    [self createAndHookKVOClass];
    [self pmy_initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (nullable instancetype)pmy_initWithCoder:(NSCoder *)aDecoder {
    [self createAndHookKVOClass];
    [self pmy_initWithCoder:aDecoder];
    return self;
}

- (void)createAndHookKVOClass {
    // Setup KVO, which trigger runtime to create the KVO subclass of VC.
    [self addObserver:[Fake_KVO_Observer shared] forKeyPath:kUniqueFakeKeyPath options:NSKeyValueObservingOptionNew context:nil];
    
    // Setup remover of KVO, automatically remove KVO when VC dealloc.
    Fake_KVO_Remover *remover = [[Fake_KVO_Remover alloc] init];
    remover.target = self;
    remover.keyPath = kUniqueFakeKeyPath;
    objc_setAssociatedObject(self, &kAssociatedRemoverKey, remover, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // NSKVONotifying_ViewController
    Class kvoCls = object_getClass(self);
    
    // Compare current Imp with our Imp. Make sure we didn't hooked before.
    IMP currentViewDidLoadImp = class_getMethodImplementation(kvoCls, @selector(viewDidLoad));
    if (currentViewDidLoadImp == (IMP)profiler_viewDidLoad) {
        return;
    }
    
    // ViewController
    Class originCls = class_getSuperclass(kvoCls);
    
    VCLog(@"Hook %@", kvoCls);
    
    // 获取原来实现的encoding
    const char *originLoadViewEncoding = method_getTypeEncoding(class_getInstanceMethod(originCls, @selector(loadView)));
    const char *originViewDidLoadEncoding = method_getTypeEncoding(class_getInstanceMethod(originCls, @selector(viewDidLoad)));
    const char *originViewDidAppearEncoding = method_getTypeEncoding(class_getInstanceMethod(originCls, @selector(viewDidAppear:)));
    const char *originViewWillAppearEncoding = method_getTypeEncoding(class_getInstanceMethod(originCls, @selector(viewWillAppear:)));
    
    // 重点，添加方法。
    class_addMethod(kvoCls, @selector(loadView), (IMP)profiler_loadView, originLoadViewEncoding);
    class_addMethod(kvoCls, @selector(viewDidLoad), (IMP)profiler_viewDidLoad, originViewDidLoadEncoding);
    class_addMethod(kvoCls, @selector(viewDidAppear:), (IMP)profiler_viewDidAppear, originViewDidAppearEncoding);
    class_addMethod(kvoCls, @selector(viewWillAppear:), (IMP)profiler_viewWillAppear, originViewWillAppearEncoding);
}

#pragma mark - IMP of Key Method

static void profiler_loadView(UIViewController *kvo_self, SEL _sel) {
    Class kvo_cls = object_getClass(kvo_self);
    Class origin_cls = class_getSuperclass(kvo_cls);
    IMP origin_imp = method_getImplementation(class_getInstanceMethod(origin_cls, _sel));
    assert(origin_imp != NULL);
    
    void (*func)(UIViewController *, SEL) = (void (*)(UIViewController *, SEL))origin_imp;
    
    
    VCLog(@"*********************\n");
    VCLog(@"VC: %p -loadView begin  at CF time:\t%lf", kvo_self, CFAbsoluteTimeGetCurrent());
    CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
    func(kvo_self, _sel);
    VCLog(@"VC: %p -loadView finish at CF time:\t%lf", kvo_self, CFAbsoluteTimeGetCurrent());
    CFTimeInterval duration = CFAbsoluteTimeGetCurrent()-time;
    VCLog(@"VC: %p cost %g in loadView", kvo_self, duration);
}

static void profiler_viewDidLoad(UIViewController *kvo_self, SEL _sel) {
    Class kvo_cls = object_getClass(kvo_self);
    Class origin_cls = class_getSuperclass(kvo_cls);
    IMP origin_imp = method_getImplementation(class_getInstanceMethod(origin_cls, _sel));
    assert(origin_imp != NULL);
    
    void (*func)(UIViewController *, SEL) = (void (*)(UIViewController *, SEL))origin_imp;
    
    
    VCLog(@"*********************\n");
    VCLog(@"VC: %p -viewDidLoad begin  at CF time:\t%lf", kvo_self, CFAbsoluteTimeGetCurrent());
    CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
    func(kvo_self, _sel);
    VCLog(@"VC: %p -viewDidLoad finish at CF time:\t%lf", kvo_self, CFAbsoluteTimeGetCurrent());
    CFTimeInterval duration = CFAbsoluteTimeGetCurrent()-time;
    VCLog(@"VC: %p cost %g in viewDidLoad", kvo_self, duration);
}

static void profiler_viewWillAppear(UIViewController *kvo_self, SEL _sel, BOOL animated) {
    Class kvo_cls = object_getClass(kvo_self);
    Class origin_cls = class_getSuperclass(kvo_cls);
    
    IMP origin_imp = method_getImplementation(class_getInstanceMethod(origin_cls, _sel));
    assert(origin_imp != NULL);
    
    void (*func)(UIViewController *, SEL, BOOL) = (void (*)(UIViewController *, SEL, BOOL))origin_imp;
    
    VCLog(@"*********************\n");
    VCLog(@"VC: %p -viewWillAppear begin  at CF time:\t%lf", kvo_self, CFAbsoluteTimeGetCurrent());
    CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
    func(kvo_self, _sel, animated);
    VCLog(@"VC: %p -viewWillAppear finish at CF time:\t%lf", kvo_self, CFAbsoluteTimeGetCurrent());
    CFTimeInterval duration = CFAbsoluteTimeGetCurrent()-time;
    VCLog(@"VC: %p cost %g in viewWillAppear", kvo_self, duration);
}

static void profiler_viewDidAppear(UIViewController *kvo_self, SEL _sel, BOOL animated) {
    Class kvo_cls = object_getClass(kvo_self);
    Class origin_cls = class_getSuperclass(kvo_cls);
    IMP origin_imp = method_getImplementation(class_getInstanceMethod(origin_cls, _sel));
    assert(origin_imp != NULL);
    
    void (*func)(UIViewController *, SEL, BOOL) = (void (*)(UIViewController *, SEL, BOOL))origin_imp;
    

    VCLog(@"*********************\n");
    VCLog(@"VC: %p -viewDidAppear begin  at CF time:\t%lf", kvo_self, CFAbsoluteTimeGetCurrent());
    CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
    func(kvo_self, _sel, animated);
    VCLog(@"VC: %p -viewDidAppear finish at CF time:\t%lf", kvo_self, CFAbsoluteTimeGetCurrent());
    CFTimeInterval duration = CFAbsoluteTimeGetCurrent()-time;
    VCLog(@"VC: %p cost %g in viewDidAppear", kvo_self, duration);
}

+ (void)swizzleMethodInClass:(Class) class originalMethod:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector
{
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

@end
