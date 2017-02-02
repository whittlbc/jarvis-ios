//
//  SocketController.swift
//  Speech
//
//  Created by Ben Whittle on 1/26/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit
import SocketIO
import AVFoundation

class SocketController {
  var socket: SocketIOClient!
  var env: Env!
  var token: String?
  
  init(token: String?) {
    self.token = token
    self.env = Env()
  }
  
  func open() -> Void {
    var headers = [String: String]()
    headers[self.env.fetch(key: "SESSION_HEADER")] = self.token
    
    self.socket = SocketIOClient(socketURL: URL(string: self.env.fetch(key: "APP_URL"))!, config: [.log(true), .forcePolling(true), .nsp("/master"), .extraHeaders(headers)])
    
    self.addListeners()
    self.socket.connect()
  }
  
  func addListeners() -> Void {
    self.socket.on("connect") {data, ack in
      print("socket connected")
    }
    
    self.socket.on("response") {data, ack in
      if let resp = data[0] as? NSDictionary {
        self.handleResponse(resp: resp)
      }
    }
  }
  
  func sendMessage(data: NSDictionary) -> Void {
    print("SENDING MESSAGE: \(data)")
    self.socket.emit("message", data)
  }
  
  func handleResponse(resp: NSDictionary) -> Void {
    let text = resp["text"] as? String
    let soundbiteUrl = resp["soundbiteUrl"] as? String
    let withVoice = resp["withVoice"] as! Bool
    let attachments = resp["attachments"] as? NSDictionary
    // take care of ts too
    
    print("Got Response: \(text) with attachments: \(attachments)")
    
    // add message to feed
    
    if (withVoice && soundbiteUrl == nil) {
      let synth = AVSpeechSynthesizer()
      let utterance = AVSpeechUtterance(string: text!)
      
      utterance.rate = 0.48
      utterance.pitchMultiplier = 1.25
      
      for voice in AVSpeechSynthesisVoice.speechVoices() {
        if #available(iOS 9.0, *) {
          if voice.name == "Daniel" {
            utterance.voice = voice
            utterance.rate = 0.5
            utterance.pitchMultiplier = 1.3
          }
        } 
      }
      
      synth.speak(utterance)
    }
    
    if (soundbiteUrl != nil) {
      let data = ["urlString": soundbiteUrl!] as [String : Any]
      NotificationCenter.default.post(name: Notification.Name("soundbite:play"), object: data)
    }
  }
  
}
