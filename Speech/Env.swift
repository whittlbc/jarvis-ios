//
//  Env.swift
//  Speech
//
//  Created by Ben Whittle on 1/30/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit

class Env {
  var configVars: NSDictionary
  
  init () {
    self.configVars = Bundle.main.infoDictionary! as NSDictionary
  }
  
  func fetch(key: String) -> String {
    return self.configVars[key] as! String
  }
  
}
