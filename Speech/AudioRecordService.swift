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

class AudioRecordService: NSObject, AudioControllerDelegate {
  var audioData: NSMutableData!
  var audioSession: AVAudioSession!
  var attentionSound: AVAudioPlayer!
  var audioHelper: AudioHelper!
  var listeningForPrompt: Bool
  var listeningForCommand: Bool
  var attentionPrompts: NSArray
  var customPrompts: NSArray
  var botName: String
  
  init(attentionPrompts: NSArray, customPrompts: NSArray) {
    self.attentionPrompts = attentionPrompts
    self.customPrompts = customPrompts
    self.audioData = NSMutableData()
    self.audioHelper = AudioHelper()
    self.listeningForPrompt = true
    self.listeningForCommand = false
    
    if let botName = UserDefaults.standard.string(forKey: "bot:name") {
      self.botName = botName
    } else {
      self.botName = "Jarvis"
    }
    
    let soundPath = Bundle.main.path(forResource: "attention", ofType: "wav")
    let soundPathUrl = URL(fileURLWithPath: soundPath!)
    
    do {
      try self.attentionSound = AVAudioPlayer(contentsOf: soundPathUrl)
    } catch {}
    
    super.init()
    
    AudioController.sharedInstance.delegate = self
    self.audioSession = AVAudioSession.sharedInstance()
    
    do {
      try self.audioSession.setCategory(AVAudioSessionCategoryRecord)
    } catch {}
    
    self.addEventListeners()
  }
  
  func addEventListeners() -> Void {
    NotificationCenter.default.addObserver(self, selector: #selector(doneSpeaking), name: NSNotification.Name(rawValue: "speech:done"), object:nil)
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
            } else if (error.localizedDescription.hasPrefix("Audio data is being streamed too fast")) {
              print("Audio is being streamed too fast..restarting after 1 second.")
              Timer.scheduledTimer(timeInterval: 1.0, target: strongSelf, selector: #selector(strongSelf.recordAudio), userInfo: nil, repeats: false)
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
        let topResult = (result.alternativesArray[0] as! SpeechRecognitionAlternative).transcript!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if (self.listeningForPrompt) {
          if (self.triggeredBotAttention(text: topResult as NSString)) {
            self.stopAudio()
            self.listeningForPrompt = false
            self.attentionSound.play()
          } else if (result.isFinal) {
            let prompt = self.getMatchingCustomPrompt(text: topResult as NSString)
            
            if (prompt != nil) {
              if let responses = prompt!["responses"] as? NSArray {
                if (responses.count > 0) {
                  // get a random response from the options
                  let randomIndex = Int(arc4random_uniform(UInt32(responses.count)))
                  let response = self.correctedString(text: responses[randomIndex] as! String)
                  
                  self.stopAudio()
                  self.audioHelper.speak(text: response)
                  return
                }
              }
            }
          }
        }
        
        if (self.listeningForCommand && result.isFinal) {
          self.listeningForCommand = false
          self.listeningForPrompt = true
          
          let data = ["text": topResult, "withVoice": true] as [String : Any]
          NotificationCenter.default.post(name: Notification.Name("voiceCommand:new"), object: data)
        }
        
        if (!self.listeningForPrompt && !self.listeningForCommand && result.isFinal) {
          self.recordAudio();
          self.listeningForCommand = true;
        }
      }
    }
  }
  
  func triggeredBotAttention(text: NSString) -> Bool {
    for p in self.attentionPrompts {
      let pattern = self.correctedString(text: p as! String)
      let regex = try! NSRegularExpression(pattern: pattern, options: [NSRegularExpression.Options.caseInsensitive])
      let results = regex.matches(in: text as String, options: [], range: NSMakeRange(0, text.length))
      
      if (!results.isEmpty) {
        return true
      }
    }
    
    return false
  }
  
  func correctedString(text: String) -> String {
    return text.replacingOccurrences(of: "<BOT_NAME>", with: UserDefaults.standard.string(forKey: "bot:name")!).replacingOccurrences(of: "<USER_NAME>", with: UserDefaults.standard.string(forKey: "user:name")!)
  }
  
  func getMatchingCustomPrompt(text: NSString) -> NSDictionary? {
    var matchingPrompt: NSMutableDictionary = [:]
    
    for prompt in self.customPrompts {
      matchingPrompt = prompt as! NSMutableDictionary
      
      if var pattern = matchingPrompt["pattern"] as? String {
        pattern = self.correctedString(text: pattern)
        let regex = try! NSRegularExpression(pattern: pattern, options: [NSRegularExpression.Options.caseInsensitive])
        let results = regex.matches(in: text as String, options: [], range: NSMakeRange(0, text.length))

        if (results.isEmpty) {
          continue
        } else {
          let groups = results.map { result in
            (0..<result.numberOfRanges).map { result.rangeAt($0).location != NSNotFound
              ? text.substring(with: result.rangeAt($0))
              : ""
            }
          }[0]
         
          matchingPrompt["groups"] = groups
          return matchingPrompt as NSDictionary
        }
      }
    }
    
    return nil
  }
  
  func doneSpeaking(notification: NSNotification) {
    self.recordAudio()
  }
  
}
