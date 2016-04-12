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
  // Swift requires initial properties
  var playerIndex: CInt = 0, lastButtonFlags: CInt = 0, emulatingButtonFlags: CInt = 0
  var lastLeftTrigger: CChar = 0, lastRightTrigger: CChar = 0
  var lastLeftStickX: CShort = 0, lastLeftStickY: CShort = 0, lastRightStickX: CShort = 0, lastRightStickY: CShort = 0
}
