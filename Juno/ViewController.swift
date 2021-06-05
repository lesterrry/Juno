//
//  ViewController.swift
//  Juno
//
//  Created by Lesterrry on 05.06.2021.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var dummyImageView: NSImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func viewDidAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.spinDisk()
        }
    }

    func spinDisk() {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.byValue = Double.pi * -2.0
        rotateAnimation.duration = 1
        rotateAnimation.repeatCount = .infinity
        
        dummyImageView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        dummyImageView.layer?.position = CGPoint(x: dummyImageView.frame.origin.x + dummyImageView.frame.width / 2,
                                             y: dummyImageView.frame.origin.y + dummyImageView.frame.height / 2)
        dummyImageView.layer?.add(rotateAnimation, forKey: nil)
    }
}

