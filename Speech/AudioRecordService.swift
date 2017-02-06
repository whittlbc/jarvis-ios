//
//  AudioRecordService.swift
//  Speech
//
//  Created by Ben Whittle on 1/26/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit
import AVFoundation
import googleapis

let SAMPLE_RATE = 16000
let BOT_NAME = "Jarvis"
let ATTENTION_SOUND_PATH = "attention.wav"

class AudioRecordService: AudioControllerDelegate {
  var audioData: NSMutableData!
  var audioSession: AVAudioSession!
  var attentionSound: AVAudioPlayer!
  var listeningForPrompt: Bool
  var listeningForCommand: Bool
  
  init() {
    self.audioData = NSMutableData()
    self.listeningForPrompt = true
    self.listeningForCommand = false
    
    let soundPath = Bundle.main.path(forResource: "attention", ofType: "wav")
    let soundPathUrl = URL(fileURLWithPath: soundPath!)
    
    do {
      try self.attentionSound = AVAudioPlayer(contentsOf: soundPathUrl)
    } catch {}
    
    AudioController.sharedInstance.delegate = self
    self.audioSession = AVAudioSession.sharedInstance()
    
    do {
      try self.audioSession.setCategory(AVAudioSessionCategoryRecord)
    } catch {}
    
  }
  
  func perform() -> Void {
    self.recordAudio()
    print("Listening...")
  }
  
  func recordAudio() -> Void {
    self.audioData = NSMutableData()
    AudioController.sharedInstance.prepare(specifiedSampleRate: SAMPLE_RATE)
    SpeechRecognitionService.sharedInstance.sampleRate = SAMPLE_RATE
    AudioController.sharedInstance.start()
  }
  
  func stopAudio() -> Void {
    AudioController.sharedInstance.stop()
    SpeechRecognitionService.sharedInstance.stopStreaming()
  }
  
  func processSampleData(_ data: Data) -> Void {
    self.audioData.append(data)
    
    // We recommend sending samples in 100ms chunks
    let chunkSize : Int /* bytes/chunk */ = Int(0.1 /* seconds/chunk */
      * Double(SAMPLE_RATE) /* samples/second */
      * 2 /* bytes/sample */);
    
    if (self.audioData.length > chunkSize) {
      SpeechRecognitionService.sharedInstance.streamAudioData(audioData,
                                                              completion:
        { [weak self] (response, error) in
          guard let strongSelf = self else {
            return
          }
          
          if let error = error {
            print("Error: \(error.localizedDescription)")
            
            // stop streaming audio
            strongSelf.stopAudio()
            
            // reset bools
            strongSelf.listeningForPrompt = true
            strongSelf.listeningForCommand = false
            
            if (error.localizedDescription.hasPrefix("Audio data is being streamed too slow")) {
              print("Disabling speech recognition. Wifi currently not fast enough.")
            } else {
              print("Restarting...")
              strongSelf.recordAudio()
            }
          } else if let response = response {
            strongSelf.handleResponse(response: response)
          }
      })
      self.audioData = NSMutableData()
    }
  }
  
  func handleResponse(response: StreamingRecognizeResponse) {
    for result in response.resultsArray! {
      if let result = result as? StreamingRecognitionResult {
        let topResult = (result.alternativesArray[0] as! SpeechRecognitionAlternative).transcript
        let topResultWords = topResult?.lowercased().components(separatedBy: " ")
        let containsBotName = topResultWords?.contains(BOT_NAME.lowercased())

        print(topResult!)
        
        if (self.listeningForPrompt && containsBotName!) {
          self.stopAudio()
          self.listeningForPrompt = false
          self.attentionSound.play()
        }
        
        if (self.listeningForCommand && result.isFinal) {
          self.listeningForCommand = false
          self.listeningForPrompt = true
          
          let data = ["text": topResult!, "withVoice": true] as [String : Any]

          NotificationCenter.default.post(name: Notification.Name("voiceCommand:new"), object: data)
        }
        
        if (!self.listeningForPrompt && !self.listeningForCommand && result.isFinal) {
          self.recordAudio();
          self.listeningForCommand = true;
        }
      }
    }
  }
  
}
