//
//  AudioHelper.swift
//  Speech
//
//  Created by Ben Whittle on 1/27/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit
import AVFoundation
import AWSPolly

class AudioHelper: NSObject, AVSpeechSynthesizerDelegate {
  var player: AVPlayer!
  var synth: AVSpeechSynthesizer!
  var speaking: Bool
  var speechEndData: NSDictionary?
  
  override init() {
    self.speaking = false
    self.speechEndData = nil
    
    super.init()
    
    self.synth = AVSpeechSynthesizer()
    self.synth.delegate = self
    
    self.player = AVPlayer()
  }
  
  func playAudioWithUrl(urlString: String) -> Void {
    let url = URL(string: urlString)
    self.playAndSubscribeToPlayerItem(withUrl: url!)
  }
  
  func speak(text: String, emitOnSpeechEnd: NSDictionary?) -> Void {
    if (speaking) {
      return;
    }
    
    self.speaking = true
    self.speechEndData = emitOnSpeechEnd
    
    let req = AWSPollySynthesizeSpeechURLBuilderRequest()
    req.text = text
    
    // We expect the output in MP3 format
    req.outputFormat = AWSPollyOutputFormat.mp3
    
    // Use the voice we selected earlier using picker to synthesize
    req.voiceId = AWSPollyVoiceId.joanna
    
    // Create an task to synthesize speech using the given synthesis input
    let builder = AWSPollySynthesizeSpeechURLBuilder.default().getPreSignedURL(req)
    
    // Request the URL for synthesis result
    builder.continueOnSuccessWith { (awsTask: AWSTask<NSURL>) -> Any? in
      let url = awsTask.result!
      self.playAndSubscribeToPlayerItem(withUrl: url as URL)
      
      return nil
    }
  }
  
  func playAndSubscribeToPlayerItem(withUrl: URL) -> Void {
    let playerItem = AVPlayerItem(url: withUrl)
    
    // subscribe to this items onEnd event
    NotificationCenter.default.addObserver(self, selector: #selector(itemDidFinishPlaying), name:NSNotification.Name.AVPlayerItemDidPlayToEndTime, object:playerItem)
    
    self.player.replaceCurrentItem(with: playerItem)
    self.player.play()
  }
  
  func itemDidFinishPlaying(notification: NSNotification) {
    self.speaking = false
    NotificationCenter.default.post(name: Notification.Name("speech:done"), object: self.speechEndData)
  }
}






