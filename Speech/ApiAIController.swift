//
//  ApiAIController.swift
//  Speech
//
//  Created by Ben Whittle on 2/5/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit
import ApiAI

class ApiAIController {

    func getIntent(query: String) -> Void {
        let request = ApiAI.shared().textRequest()
        request?.query = [query]
        
        request?.setMappedCompletionBlockSuccess({ (request, response) in
            let response = response as! AIResponse
            let data = ["response": response] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name("apiai:response"), object: data)
        }, failure: { (request, error) in
            print("Error fetching intent from Api.ai: \(error)")
        })
        
        ApiAI.shared().enqueue(request)
    }
    
}
