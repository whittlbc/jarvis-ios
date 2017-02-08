//
//  AudioHelper.swift
//  Speech
//
//  Created by Ben Whittle on 1/27/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit
import AVFoundation

class AudioHelper: NSObject, AVSpeechSynthesizerDelegate {
  var player: AVPlayer!
  var synth: AVSpeechSynthesizer!
  
  override init() {
    super.init()
    self.synth = AVSpeechSynthesizer()
    self.synth.delegate = self
  }
  
  func playAudioWithUrl(urlString: String) -> Void {
    let url = URL(string: urlString)
    let playerItem = AVPlayerItem(url: url!)
    
    self.player = AVPlayer(playerItem: playerItem)
    self.player.rate = 1.0;
    self.player.play()
  }
  
  func speak(text: String) -> Void {
    let utterance = AVSpeechUtterance(string: text)
//    utterance.rate = 0.48
//    utterance.pitchMultiplier = 1.25
    self.synth.speak(utterance)
  }
  
  func speechSynthesizer(_:AVSpeechSynthesizer, didFinish: AVSpeechUtterance) {
    NotificationCenter.default.post(name: Notification.Name("speech:done"), object: nil)
  }
}
