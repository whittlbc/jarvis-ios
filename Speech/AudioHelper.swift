//
//  AudioHelper.swift
//  Speech
//
//  Created by Ben Whittle on 1/27/17.
//  Copyright © 2017 Google. All rights reserved.
//

import UIKit
import AVFoundation

class AudioHelper: NSObject {
  var player: AVPlayer!
  
  func playAudioWithUrl(urlString: String) -> Void {
    let url = URL(string: urlString)
    let playerItem = AVPlayerItem(url: url!)
    
    self.player = AVPlayer(playerItem: playerItem)
    self.player.rate = 1.0;
    self.player.play()
  }
}
