//
//  UIViewController+LoadTimeProfiler.h
//  VCLoadTimeProfiler
//
//  Created by Brooks on 2018/8/16.
//

#import <UIKit/UIKit.h>

@interface Fake_KVO_Observer : NSObject
@end


#pragma mark -

@interface Fake_KVO_Remover : NSObject

@property (nonatomic, unsafe_unretained) id target;
@property (nonatomic, copy) NSString *keyPath;

@end


#pragma mark -

@interface UIViewController (LoadTimeProfiler)

@end
