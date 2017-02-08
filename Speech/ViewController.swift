//
// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import UIKit
import ApiAI
import AVFoundation

class ViewController : UIViewController {
  var socketController: SocketController!
  var audioRecordService: AudioRecordService!
  var audioHelper: AudioHelper!
  var requests: Requests!
  var loginController: LoginController!
  var env: Env!
  var apiaiController: ApiAIController!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.apiaiController = ApiAIController()
    
    self.env = Env()
    self.requests = Requests()
    
    // If session token has been stored locally, use that for auth.
    if let sessionToken = UserDefaults.standard.string(forKey: self.env.fetch(key: "SESSION_HEADER")) {
      self.requests.setSession(token: sessionToken)
    }
    
    self.loginController = LoginController(requests: self.requests)

    self.addEventListeners()
    
    if (self.requests.token == nil) {
      self.loginController.login()
    } else {
      self.connectToSocket()
    }
  }
  
  func addEventListeners() -> Void {
    NotificationCenter.default.addObserver(self, selector: #selector(handleNewVoiceCommand), name: NSNotification.Name(rawValue: "voiceCommand:new"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(handlePlaySoundbite), name: NSNotification.Name(rawValue: "soundbite:play"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(connectToSocket), name: NSNotification.Name(rawValue: "user:authed"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(handleApiAiResp), name: NSNotification.Name(rawValue: "apiai:response"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(handleUserInfo), name: NSNotification.Name(rawValue: "user_info:fetched"), object:nil)
  }
  
  func handleNewVoiceCommand(notification: NSNotification) {
    if let dict = notification.object as? NSDictionary {
      let query = dict["text"] as! String
      self.apiaiController.getIntent(query: query)
    }
  }
  
  func handleApiAiResp(notification: NSNotification) {
    if let data = notification.object as? NSDictionary {
      let response = data["response"] as! AIResponse
      let fulfillment = response.result.fulfillment as AIResponseFulfillment
      let speech = fulfillment.speech!
      
      let action = response.result.action
      
      // use action to query a dictionary for the info you need about what to do
      

      
//      if (speech.isEmpty) {
        // Send response over to server to perform action
        // You can prolly send it all over as JSON somehow
        // self.socketController.sendMessage(data: data)
//      } else {
//        let synth = AVSpeechSynthesizer()
//        let utterance = AVSpeechUtterance(string: speech)
//        utterance.rate = 0.48
//        utterance.pitchMultiplier = 1.25
//        synth.speak(utterance)
//      }

//      let action = response.result.action
//      let params = response.result.parameters as? [String: AIResponseParameter]
    }
  }
  
  func handleUserInfo(notification: NSNotification) {
    if let data = notification.object as? NSDictionary {
      if let userName = data["user_name"] as? String {
        UserDefaults.standard.setValue(userName, forKey: "user:name")
      }
      
      if let botName = data["bot_name"] as? String {
        UserDefaults.standard.setValue(botName, forKey: "bot:name")
      }
      
      if (data["actions"] as? NSDictionary) != nil {
        let actions = data["actions"] as! NSDictionary
        var attentionPrompts = actions["attentionPropmts"] as? NSArray
        var customPrompts = actions["customPrompts"] as? NSArray
        
        if (attentionPrompts == nil) {
          attentionPrompts = ["^(hey|ok|okay|yo) <BOT_NAME>$"]
        }
        
        if (customPrompts == nil) {
          customPrompts = []
        }
        
        self.startSpeechRecognition(attentionPrompts: attentionPrompts!, customPrompts: customPrompts!)
      }
    }
  }
  
  func handlePlaySoundbite(notification: NSNotification) {
    if let data = notification.object as? NSDictionary {
      self.audioHelper.playAudioWithUrl(urlString: data["urlString"] as! String)
    }
  }
  
  // init socket and open it
  func connectToSocket() -> Void {
    self.socketController = SocketController(token: self.requests.token)
    self.socketController.open()
  }

  // init microphone audio recording/speech-recog service
  func startSpeechRecognition(attentionPrompts: NSArray, customPrompts: NSArray) -> Void {
    self.audioRecordService = AudioRecordService(attentionPrompts: attentionPrompts, customPrompts: customPrompts)
    self.audioHelper = AudioHelper()
    self.audioRecordService.perform()
  }
  
}
