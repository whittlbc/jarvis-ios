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
            // Update the Request token property
            self.requests.setSession(token: cookie!.value)
            
            // Store the session token in local storage
            UserDefaults.standard.setValue(cookie!.value, forKey: self.env.fetch(key: "SESSION_HEADER"))
            
            // Let our main ViewController know our user is now authed
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
  
  func getIntegrationOauthUrl(integrationSlug: String) -> Void {
    self.requests.get(endpoint: "/integrations/oauth_url", params: ["slug": integrationSlug] as Parameters).responseJSON { response in
      let statusCode = response.response?.statusCode
      
      if (statusCode == 200) {
        let data = try! JSONSerialization.jsonObject(with: response.data!, options: []) as? [String:AnyObject]
        
        if (data != nil)  {
          let authData: NSDictionary = ["slug": integrationSlug, "oauthUrl": data!["url"] as Any]
          NotificationCenter.default.post(name: Notification.Name("integratedUser:authed"), object: authData)
        }
      } else if (statusCode == 1005) {
        // Invalid User Permissions
      } else if (statusCode == 3000) {
        // Integration not found
      } else {
        // Other
      }
    }
    
  }
  
}
