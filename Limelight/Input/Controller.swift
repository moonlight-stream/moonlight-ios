//
//  Controller.swift
//  Moonlight
//
//  Created by David Aghassi on 4/11/16.
//  Copyright © 2016 Moonlight Stream. All rights reserved.
//

import Foundation

@objc
class Controller: NSObject {
  var playerIndex, lastButtonFlags, emulatingButtonFlags: Int
  var lastLeftTrigger, lastRightTrigger: Character
  var lastLeftStickX, lastLeftStickY, lastRightStickX, lastRightStickY: CShort
}
