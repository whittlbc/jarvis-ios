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
    self.socket.on("user_info:fetched") {data, ack in
      if let resp = data[0] as? NSDictionary {
        NotificationCenter.default.post(name: Notification.Name("user_info:fetched"), object: resp)
      }
    }
    
    self.socket.on("connect") {data, ack in
      self.socket.emit("fetch:user_info")
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
    
    print("Got Response: \(text!) with attachments: \(attachments!)")
    
    // add message to feed
    
    if (withVoice && soundbiteUrl == nil) {
      let data = ["text": text!] as [String : Any]
      NotificationCenter.default.post(name: Notification.Name("text:speak"), object: data)
    }
    
    if (soundbiteUrl != nil) {
      let data = ["urlString": soundbiteUrl!] as [String : Any]
      NotificationCenter.default.post(name: Notification.Name("soundbite:play"), object: data)
    }
  }
  
}
