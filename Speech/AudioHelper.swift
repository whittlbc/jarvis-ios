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

let attentionPromptTextResponses: NSArray = ["What's up?", "Yes?"]

class AudioHelper: NSObject, AVSpeechSynthesizerDelegate {
  var player: AVPlayer!
  var synth: AVSpeechSynthesizer!
  var speaking: Bool
  var speechEndData: NSDictionary?
  var attentionPromptResponses: Array<AVPlayerItem>
  
  override init() {
    self.speaking = false
    self.speechEndData = nil
    self.attentionPromptResponses = []
    
    super.init()
    
    self.synth = AVSpeechSynthesizer()
    self.synth.delegate = self
    
    self.player = AVPlayer()
    self.prepareAttentionPromptResponses()
  }
  
  func prepareAttentionPromptResponses() -> Void {
    for botResponse in attentionPromptTextResponses {
      let builder = self.createSpeechURLBuilder(text: botResponse as! String)
      
      builder.continueOnSuccessWith { (awsTask: AWSTask<NSURL>) -> Any? in
        let url = awsTask.result! as URL
        self.attentionPromptResponses.append(AVPlayerItem(url: url))
        return nil
      }
    }
  }
  
  func playAudioWithUrl(urlString: String) -> Void {
    let url = URL(string: urlString)
    self.playAndSubscribeToPlayerItem(withUrl: url!)
  }
  
  func playAttentionPromptResponse() -> Void {
    if (self.attentionPromptResponses.count > 0 && !self.speaking) {
      self.speaking = true
      let randomIndex = Int(arc4random_uniform(UInt32(self.attentionPromptResponses.count)))
      let response = self.attentionPromptResponses[randomIndex]
      
      // subscribe to this items onEnd event
      NotificationCenter.default.addObserver(self, selector: #selector(itemDidFinishPlaying), name:NSNotification.Name.AVPlayerItemDidPlayToEndTime, object:response)
      
      self.player.replaceCurrentItem(with: response)
      self.player.play()
    }
  }
  
  func speak(text: String, emitOnSpeechEnd: NSDictionary?) -> Void {
    if (self.speaking) {
      return;
    }
    
    self.speaking = true
    self.speechEndData = emitOnSpeechEnd
    
    let builder = self.createSpeechURLBuilder(text: text)
    
    builder.continueOnSuccessWith { (awsTask: AWSTask<NSURL>) -> Any? in
      let url = awsTask.result!
      self.playAndSubscribeToPlayerItem(withUrl: url as URL)
      
      return nil
    }
  }
  
  func createSpeechURLBuilder(text: String) -> AWSTask<NSURL> {
    let req = AWSPollySynthesizeSpeechURLBuilderRequest()
    req.text = text
    
    // We expect the output in MP3 format
    req.outputFormat = AWSPollyOutputFormat.mp3
    
    // Use the voice we selected earlier using picker to synthesize
    req.voiceId = AWSPollyVoiceId.joanna
    
    // Create an task to synthesize speech using the given synthesis input
    return AWSPollySynthesizeSpeechURLBuilder.default().getPreSignedURL(req)
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






