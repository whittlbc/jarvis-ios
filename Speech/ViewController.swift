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
  }
  
  func handleNewVoiceCommand(notification: NSNotification) {
    print("Heard handle voice command")
    if let dict = notification.object as? NSDictionary {
      let query = dict["text"] as! String
      print("Query: \(query)")
      self.apiaiController.getIntent(query: query)
    }
  }
  
  func handleApiAiResp(notification: NSNotification) {
    if let data = notification.object as? NSDictionary {
      let response = data["response"] as! AIResponse
      let fulfillment = response.result.fulfillment as AIResponseFulfillment
      let speech = fulfillment.speech!
      
      if (speech.isEmpty) {
        // Send response over to server to perform action
        // You can prolly send it all over as JSON somehow
        // self.socketController.sendMessage(data: data)
      } else {
        let synth = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: speech)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.25
        synth.speak(utterance)
      }

//      let action = response.result.action
//      let params = response.result.parameters as? [String: AIResponseParameter]
    }
  }
  
  func handlePlaySoundbite(notification: NSNotification) {
    if let data = notification.object as? NSDictionary {
      self.audioHelper.playAudioWithUrl(urlString: data["urlString"] as! String)
    }
  }
  
  func connectToSocket() -> Void {
    // init socket and open it
    self.socketController = SocketController(token: self.requests.token)
    self.socketController.open()
    
    self.startSpeechRecognition()
  }
  
  func startSpeechRecognition() -> Void {
    // init microphone audio recording/speech-recog service
    self.audioRecordService = AudioRecordService()
    self.audioHelper = AudioHelper()
    self.audioRecordService.perform()
  }
  
}
