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
import MapKit
import CoreLocation

class ViewController : UIViewController, CLLocationManagerDelegate {
  var socketController: SocketController!
  var audioRecordService: AudioRecordService!
  var audioHelper: AudioHelper!
  var requests: Requests!
  var loginController: LoginController!
  var env: Env!
  var apiaiController: ApiAIController!
  var locationManager: CLLocationManager!
  var currentLocation: NSMutableDictionary?

  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.apiaiController = ApiAIController()
    self.setupLocationManager()
    self.env = Env()
    self.requests = Requests()
    
    self.currentLocation = [:]
    
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
  
  @IBAction func buttonClicked(_ sender: Any) {
    self.loginController.getIntegrationOauthUrl(integrationSlug: "uber")
  }
  
  func setupLocationManager() -> Void {
    self.locationManager = CLLocationManager()

    // Ask for Authorization from the User.
    self.locationManager.requestAlwaysAuthorization()
    
    // For use in foreground
    self.locationManager.requestWhenInUseAuthorization()
    
    if CLLocationManager.locationServicesEnabled() {
      locationManager.delegate = self
      locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
      locationManager.startUpdatingLocation()
    }
  }
  
  func addEventListeners() -> Void {
    NotificationCenter.default.addObserver(self, selector: #selector(handleNewVoiceCommand), name: NSNotification.Name(rawValue: "voiceCommand:new"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(handlePlaySoundbite), name: NSNotification.Name(rawValue: "soundbite:play"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(connectToSocket), name: NSNotification.Name(rawValue: "user:authed"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(handleApiAiResp), name: NSNotification.Name(rawValue: "apiai:response"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(handleUserInfo), name: NSNotification.Name(rawValue: "user_info:fetched"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(handleSpeechResponse), name: NSNotification.Name(rawValue: "text:speak"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(continueConversation), name: NSNotification.Name(rawValue: "conversation:continue"), object:nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(openAuthUrl), name: NSNotification.Name(rawValue: "integratedUser:authed"), object:nil)
  }
  
  func openAuthUrl(notification: NSNotification) {
    if let data = notification.object as? NSDictionary {
      let urlString = data["oauthUrl"] as? String
      
      if (urlString != nil) {
        let url = URL(string: urlString!)
        if #available(iOS 10.0, *) {
          UIApplication.shared.open(url!)
        } else {
          UIApplication.shared.openURL(url!)
        }
      }
    }
  }
  
  func continueConversation(notification: NSNotification) {
    if let data = notification.object as? NSDictionary {
      let params: NSDictionary = ["resource_uid": data["resource_uid"]!]
      
      let intent = [
        "query": data["text"]!,
        "action": data["action"]!,
        "params": params
        ] as NSDictionary
      
      let dt = self.currentDatetime().components(separatedBy: " ")
      let userMetadata = ["date": dt[0], "time": dt[1], "location": self.currentLocation!] as NSDictionary
      
      let data = [
        "intent": intent,
        "userMetadata": userMetadata,
        "withVoice": data["withVoice"]!
        ] as NSDictionary
      
      self.socketController.sendMessage(data: data)
    }
  }
  
  func handleSpeechResponse(notification: NSNotification) {
    if let dict = notification.object as? NSDictionary {
      self.audioHelper.speak(text: dict["text"] as! String, emitOnSpeechEnd: dict["prompt"] as? NSDictionary)
    }
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
      
      if (!speech.isEmpty) {
        self.audioHelper.speak(text: speech, emitOnSpeechEnd: nil)
      }
      
      let intent = [
        "query": response.result.resolvedQuery,
        "action": response.result.action
      ] as NSMutableDictionary
      
      var params: NSMutableDictionary = [:]
      
      if let parameters = response.result.parameters as? [String: AIResponseParameter]{
        for (k, v) in parameters {
          params[k] = v.stringValue
        }
      }
      
      intent["params"] = params
      
      if (response.result.action != "input.unknown") {
        let dt = self.currentDatetime().components(separatedBy: " ")
        let userMetadata = ["date": dt[0], "time": dt[1], "location": self.currentLocation!] as NSDictionary
        let data = [
          "intent": intent as NSDictionary,
          "userMetadata": userMetadata,
          "withVoice": true
        ] as NSDictionary
      
        self.socketController.sendMessage(data: data)
      }
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
        var attentionPrompt = actions["attentionPrompt"] as? String
        var customPrompts = actions["customPrompts"] as? NSArray
        
        if (attentionPrompt == nil) {
          attentionPrompt = "^(hey |ok |okay |yo |)(<BOT_NAME>|Jarvis)(.*)"
        }
        
        if (customPrompts == nil) {
          customPrompts = []
        }
        
        self.startSpeechRecognition(attentionPrompt: attentionPrompt!, customPrompts: customPrompts!)
      }
    }
  }
  
  func handlePlaySoundbite(notification: NSNotification) {
    if let data = notification.object as? NSDictionary {
      self.audioHelper.playAudioWithUrl(urlString: data["urlString"] as! String)
      // TODO: Need to figure out how to add a callback to ^this so that you know exactly when to utilize postResponsePrompt if you need to.
    }
  }
  
  // init socket and open it
  func connectToSocket() -> Void {
    self.socketController = SocketController(token: self.requests.token)
    self.socketController.open()
  }

  // init microphone audio recording/speech-recog service
  func startSpeechRecognition(attentionPrompt: String, customPrompts: NSArray) -> Void {
    self.audioHelper = AudioHelper()
    self.audioRecordService = AudioRecordService(audioHelper: self.audioHelper, attentionPrompt: attentionPrompt, customPrompts: customPrompts)
    self.audioRecordService.perform()
  }
  
  func currentDatetime() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: Date())
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let locValue: CLLocationCoordinate2D = manager.location!.coordinate
    // Hard coding for now
    let coordinates: NSDictionary = ["lat": 37.458142, "lng": -122.149983]
//    let coordinates: NSDictionary = ["lat": locValue.latitude, "lng": locValue.longitude]
    
    self.currentLocation?["coordinates"] = coordinates
    
    CLGeocoder().reverseGeocodeLocation(manager.location!, completionHandler: { (placemarks, error) -> Void in
      if (error == nil) {
        var location: CLPlacemark!
        location = placemarks?[0]
        
        let keysMap: NSDictionary = [
          "Name": "name",
          "Thoroughfare": "street",
          "City": "city",
          "State": "state",
          "ZIP": "zip",
          "Country": "country",
          "CountryCode": "countryCode"
        ]
        
        for (addrKey, currLocKey) in keysMap {
          if let val = location.addressDictionary![addrKey as! String] as? NSString {
            self.currentLocation?[currLocKey as! String] = val
          }
        }
      } else {
        print("Error fetching reverse geocode location... \(error!)")
      }
    })
  }
  
}
