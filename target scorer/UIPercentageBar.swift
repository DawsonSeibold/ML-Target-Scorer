//
//  UIPercentageBar.swift
//  target scorer
//
//  Created by Dawson Seibold on 8/5/18.
//  Copyright © 2018 Smile App Development. All rights reserved.
//

import Foundation
import UIKit

class UIPercentageBar: UIView {
    
    var percentage: Float = 1.0
    var barWidth: CGFloat = 0
    var barFrame: CGRect?
    
    var barView: UIView?
    var percentView: UIView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        barFrame = CGRect(x: 0, y: 0, width: frame.width, height: 5)
        createBarView(frame: barFrame!)
        createPercentView(frame: barFrame!)
    }
    
    private func createBarView(frame: CGRect) {
        barWidth = frame.width
        barView = UIView(frame: frame)
        self.addSubview(barView!)
        
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = frame
        self.addSubview(blurEffectView)
    }
    
    private func createPercentView(frame: CGRect) {
        percentView = UIView(frame: getPercentFrame())
        percentView?.backgroundColor = UIColor.green
//        self.addSubview(percentView!)
        barView?.addSubview(percentView!)
    }
    
    private func getPercentFrame() -> CGRect {
        guard let frame = barFrame else { return CGRect.zero }
        let newWidth = (barFrame?.width)! * CGFloat(percentage)
        return CGRect(x: frame.minX, y: frame.minY, width: newWidth, height: frame.height)
    }
    
    func updatePercentage(_ percentage: Float) {
        self.percentage = percentage
        percentView?.frame = getPercentFrame()
    }
    
    
    
    
    
    
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
