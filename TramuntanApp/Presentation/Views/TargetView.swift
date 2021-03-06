//
//  TargetView.swift
//  TramuntanApp
//
//  Created by Tovkal on 14/10/14.
//  Copyright (c) 2014 Tovkal. All rights reserved.
//

import UIKit

private let sharedView = TargetView()

class TargetView: UIView {
    
    /// Class variable for the shared instance
    class var sharedInstance: TargetView {
        return sharedView
    }
    
    /// Size of the rounded rectangle, should be the size of the TargetView rect - 2
    let size: CGFloat = 25
    /// Corner radius of the rounder rectangle
    let cornerRadius: CGFloat = 4
    
    /**
    Create a TargetView with as a 27x27 view
    
    - returns: Instance
    */
    convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 27, height: 27))
        self.isOpaque = false
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
    Draw code
    
    - parameter rect: Where to draw
    */
    override func draw(_ rect: CGRect) {
        let rectangleView = UIBezierPath(roundedRect: CGRect(x: 1, y: 1, width: size, height: size), cornerRadius: cornerRadius)
        let filling = UIColor.red
        filling.setStroke()
        rectangleView.lineWidth = 1
        rectangleView.stroke()
    }
}
