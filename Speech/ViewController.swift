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

class ViewController : UIViewController {
  var socketController: SocketController!
  var audioRecordService: AudioRecordService!
  var audioHelper: AudioHelper!
  var requests: Requests!
  var loginController: LoginController!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.requests = Requests()
    self.loginController = LoginController(requests: self.requests)

    self.addEventListeners()
    self.loginController.login()
  }
  
  func addEventListeners() -> Void {
    NotificationCenter.default.addObserver(self, selector: #selector(handleNewVoiceCommand), name: NSNotification.Name(rawValue: "voiceCommand:new"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(handlePlaySoundbite), name: NSNotification.Name(rawValue: "soundbite:play"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(connectToSocket), name: NSNotification.Name(rawValue: "user:authed"), object:nil)
  }
  
  func handleNewVoiceCommand(notification: NSNotification) {
    self.socketController.sendMessage(data: notification.object as! NSDictionary)
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
