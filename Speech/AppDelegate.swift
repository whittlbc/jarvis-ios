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
import AWSCore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  let apiai = ApiAI.shared()!
  let env = Env()
  var window: UIWindow?
  
  func application
    (_ application: UIApplication,
     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil)
    -> Bool {
      
      let apiaiConfiguration: AIConfiguration = AIDefaultConfiguration()
      apiaiConfiguration.clientAccessToken = env.fetch(key: "API_AI_KEY")
      apiai.configuration = apiaiConfiguration
      
      let credentialProvider = AWSCognitoCredentialsProvider(
        regionType: AWSRegionType.USWest2,
        identityPoolId: env.fetch(key: "AWS_IDENTITY_POOL_ID")
      )
      
      let awsConfiguration = AWSServiceConfiguration(
        region: AWSRegionType.USWest2,
        credentialsProvider: credentialProvider
      )
      
      AWSServiceManager.default().defaultServiceConfiguration = awsConfiguration
      
      return true
  }
}
