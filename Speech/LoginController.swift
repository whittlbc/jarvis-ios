//
//  LoginController.swift
//  Speech
//
//  Created by Ben Whittle on 1/31/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit
import Alamofire

class LoginController {
  var env: Env!
  var requests: Requests!
  
  init(requests: Requests) {
    self.requests = requests
    self.env = Env()
  }
  
  func signup() -> Void {
    self.userAuth(method: "signup")
  }
  
  func login() -> Void {
    self.userAuth(method: "login")
  }
  
  func userAuth(method: String) -> Void {
    let params: Parameters = ["email": "benwhittle31@gmail.com", "password": "password"]
    
    self.requests.post(endpoint: ("/" + method), params: params).responseJSON { response in
      let statusCode = response.response?.statusCode
      
      if (statusCode == 200) {
        let headerFields = response.response?.allHeaderFields as? [String: String]
        let reqUrl = response.request?.url
        
        if (headerFields != nil && reqUrl != nil) {
          let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields!, for: reqUrl!)
          let cookie = cookies.first(where:{$0.name == self.env.fetch(key: "COOKIE_NAME")})
          
          if (cookie != nil) {
            self.requests.setSession(token: cookie!.value)
            NotificationCenter.default.post(name: Notification.Name("user:authed"), object: nil)
          }
        }
      } else if (statusCode == 1000) {
        // Incomplete Login Credentials
      } else if (statusCode == 1002) {
        // Email already in use
      } else {
        // General user auth error
      }
    }
  }
  
}
