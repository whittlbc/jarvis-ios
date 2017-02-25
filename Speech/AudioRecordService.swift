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
let DEFAULT_BOT_NAME = "Jarvis"
let ATTENTION_SOUND_PATH = "attention.wav"

class AudioRecordService: NSObject, AudioControllerDelegate {
  var audioData: NSMutableData!
  var audioSession: AVAudioSession!
  var attentionSound: AVAudioPlayer!
  var audioHelper: AudioHelper!
  var listeningForPrompt: Bool
  var listeningForCommand: Bool
  var listeningForConversation: Bool
  var attentionPrompt: NSRegularExpression
  var customPrompts: NSArray
  var botName: String
  var conversationData: NSDictionary
  var botIsSpeaking: Bool
  
  init(audioHelper: AudioHelper, attentionPrompt: String, customPrompts: NSArray) {
    self.audioHelper = audioHelper
    self.customPrompts = customPrompts
    self.audioData = NSMutableData()
    self.attentionPrompt = NSRegularExpression()
    self.listeningForPrompt = true
    self.listeningForCommand = false
    self.listeningForConversation = false
    self.conversationData = [:]
    self.botIsSpeaking = false
    
    if let botName = UserDefaults.standard.string(forKey: "bot:name") {
      self.botName = botName
    } else {
      self.botName = DEFAULT_BOT_NAME
    }
    
    let soundPath = Bundle.main.path(forResource: "attention", ofType: "wav")
    let soundPathUrl = URL(fileURLWithPath: soundPath!)
    
    do {
      try self.attentionSound = AVAudioPlayer(contentsOf: soundPathUrl)
    } catch {}
    
    super.init()
    
    self.attentionPrompt = try! NSRegularExpression(pattern: self.correctedString(text: attentionPrompt), options: [NSRegularExpression.Options.caseInsensitive])
    
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
    SpeechRecognitionService.sharedInstance.sampleRate = SAMPLE_RATE
    AudioController.sharedInstance.prepare(specifiedSampleRate: SAMPLE_RATE)
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
    if (self.audioHelper.speaking) {
      self.stopAudio()
    }
    
    for result in response.resultsArray! {
      if let result = result as? StreamingRecognitionResult {
        if (result.isFinal) {
          let topResult = (result.alternativesArray[0] as! SpeechRecognitionAlternative).transcript!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          
          print(topResult)
          
          if (self.listeningForConversation) {
            let data = [
              "text": topResult,
              "withVoice": true,
              "action": self.conversationData["action"]!, // do more to protect this
              "resource_uid": self.conversationData["resource_uid"]!  // do more to protect this
              ] as [String : Any]
            
            NotificationCenter.default.post(name: Notification.Name("conversation:continue"), object: data)
            
            self.listeningForConversation = false
            self.conversationData = [:]
            
          } else if (self.listeningForPrompt) {
            let nsTopResult = topResult as NSString
            
            // Check if matches attention prompt
            let attentionMatches = self.attentionPrompt.matches(in: topResult, options: [], range: NSMakeRange(0, nsTopResult.length))
            
            if (!attentionMatches.isEmpty) {
              var strMatches = [String]()
              
              for index in 1..<attentionMatches[0].numberOfRanges {
                strMatches.append(nsTopResult.substring(with: attentionMatches[0].rangeAt(index)))
              }
              
              if (strMatches.count != 3) {
                print("Attention Prompt Regex Error: The regex used for this should result in 3 groups.")
                return
              }
              
              print("ATTENTION MATCHES FOUND: \(strMatches)")
              
              var command = strMatches.popLast()!
              var gettingBotAttention: Bool = false
              
              // If no command, just prompt the bot's attention
              if (command.isEmpty) {
                gettingBotAttention = true
              }
              // if "Hey <BOT_NAME>" is followed by either a comma, a period, an exclamation, or a space, figure out if the rest of 
              // that string (the command) has any other content.
              else if (command.hasPrefix(",") || command.hasPrefix(".") || command.hasPrefix("!") || command.hasPrefix(" ")) {
                let sliced = String(command.characters.dropFirst())
                let trimmed = sliced.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                // if no content other than the the space/punctuation, just prompt the bot's attention
                if (trimmed.isEmpty) {
                  gettingBotAttention = true
                } else {  // otherwise, take the trimmed command and proceed with using that as a voice command
                  command = trimmed
                }
              } else {  // if the command is anything else, don't accept it.
                return
              }
              
              // Prompt the bot if that's what we've decided
              if (gettingBotAttention) {
                self.listeningForPrompt = false
                self.listeningForCommand = true
//                self.attentionSound.play()
                self.audioHelper.playAttentionPromptResponse()
                
              } else {  // Otherwise, emit a new voiceCommand event with our parsed command.
                let data = ["text": topResult, "withVoice": true] as [String : Any]
                NotificationCenter.default.post(name: Notification.Name("voiceCommand:new"), object: data)
              }
              
            } else {  // Figure out if the query matches any the user's custom prompts
              print("NO ATTENTION MATCHES FOUND: \(attentionMatches)")
              let prompt = self.getMatchingCustomPrompt(text: topResult as NSString)
              
              if (prompt != nil) {
                // custom prompt match was found, so find random response from the provided options, and say that.
                if let responses = prompt!["responses"] as? NSArray {
                  if (responses.count > 0) {
                    // get a random response from the options
                    let randomIndex = Int(arc4random_uniform(UInt32(responses.count)))
                    let response = self.correctedString(text: responses[randomIndex] as! String)
                    
                    self.audioHelper.speak(text: response, emitOnSpeechEnd: nil)
                    return
                  }
                }
              }
            }
          } else if (self.listeningForCommand) {
            self.listeningForCommand = false
            self.listeningForPrompt = true
            let data = ["text": topResult, "withVoice": true] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("voiceCommand:new"), object: data)
          }
        }
      }
    }
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
    
    if let data = notification.object as? NSDictionary {
      self.conversationData = data
      
      if (self.conversationData.count > 0) {
        self.listeningForConversation = true
      }
    }
  }
  
}
