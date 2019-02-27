//
//  OpenCVWrapper.m
//  target scorer
//
//  Created by Dawson Seibold on 8/5/18.
//  Copyright © 2018 Smile App Development. All rights reserved.
//

#import "OpenCVWrapper.h"
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>

@implementation OpenCVWrapper

+ (NSString *)openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

+ (UIImage *)makeGray:(UIImage *)image {
    //Transform UIImage to cv::Mat
    cv::Mat imageMat;
    UIImageToMat(image, imageMat);
    
    //If the image was already in grayscale return it
    if (imageMat.channels() == 1) return image;
    
    //Convert the cv::Mat from color to gray
    cv::Mat grayMat;
    cv::cvtColor(imageMat, grayMat, CV_BGR2GRAY);
    
    //Convert from cv::Mat image to UIImage, then return it
    return MatToUIImage(grayMat);
}

@end
