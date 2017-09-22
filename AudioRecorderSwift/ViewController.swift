//
//  ViewController.swift
//  AudioRecorderSwift
//
//  Created by pebble8888 on 2017/09/22.
//  Copyright © 2017年 pebble8888. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var progress:UIProgressView!
    @IBOutlet var label:UILabel!
    
    var recorder:MyAudioRecorder!
    var timer: Timer!
    override func viewDidLoad() {
        super.viewDidLoad()
        recorder = MyAudioRecorder()
        recorder?.start()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        timer = Timer.scheduledTimer(timeInterval: 0.005, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer.fire()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }
    
    @objc func update(tm: Timer){
        progress.progress = recorder.level
        label.text = "\(recorder.frameCount)"
    }    
}
