//
//  RequestController.swift
//  Speech
//
//  Created by Ben Whittle on 1/30/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit
import Alamofire

class Requests {
  var token: String?
  var env: Env!
  
  init () {
    self.env = Env()
  }
  
  func setSession(token: String) -> Void {
    self.token = token
  }
  
  func get(endpoint: String, params: Parameters?) -> DataRequest {
    return createRequest(endpoint: endpoint, params: params, meth: "GET")
  }
  
  func post(endpoint: String, params: Parameters?) -> DataRequest {
    return createRequest(endpoint: endpoint, params: params, meth: "POST")
  }
  
  func put(endpoint: String, params: Parameters?) -> DataRequest {
    return createRequest(endpoint: endpoint, params: params, meth: "PUT")
  }
  
  func delete(endpoint: String, params: Parameters?) -> DataRequest {
    return createRequest(endpoint: endpoint, params: params, meth: "DELETE")
  }
  
  func createRequest(endpoint: String, params: Parameters?, meth: String) -> DataRequest {
    var req: DataRequest?
    let url = self.env.fetch(key: "APP_URL") + endpoint
    
    switch meth {
    case "GET":
      req = Alamofire.request(url, method: .get, parameters: params, encoding: URLEncoding.default, headers: self.customHeaders())
    case "POST":
      req = Alamofire.request(url, method: .post, parameters: params, encoding: JSONEncoding.default, headers: self.customHeaders())
    case "PUT":
      req = Alamofire.request(url, method: .put, parameters: params, encoding: JSONEncoding.default, headers: self.customHeaders())
    case "DELETE":
      req = Alamofire.request(url, method: .delete, parameters: params, encoding: JSONEncoding.default, headers: self.customHeaders())
    default:
      return req!
    }
    
    return req!
  }
  
  func customHeaders() -> HTTPHeaders? {
    var headers: HTTPHeaders? = [:]
    
    if (self.token != nil) {
      headers?[self.env.fetch(key: "SESSION_HEADER")] = self.token
    }
    
    return headers
  }
  
  func isAuthed() -> Bool {
    return self.token != nil
  }
  
  func failed(response: DataResponse<Any>) -> Bool {
    var failed: Bool = false
    
    if (response.result.isFailure) {
      failed = true
      print("HTTP Error: \(response.error)")
    }

    return failed
  }
  
}
