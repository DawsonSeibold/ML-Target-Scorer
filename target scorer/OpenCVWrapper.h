//
//  OpenCVWrapper.h
//  target scorer
//
//  Created by Dawson Seibold on 8/5/18.
//  Copyright © 2018 Smile App Development. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

+ (NSString *)openCVVersionString;
+ (UIImage *)makeGray:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
