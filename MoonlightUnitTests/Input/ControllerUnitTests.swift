//
//  ControllerUnitTests.swift
//  Moonlight
//
//  Created by David Aghassi on 4/11/16.
//  Copyright © 2016 Moonlight Stream. All rights reserved.
//

import XCTest
@testable import Moonlight

class ControllerUnitTests: XCTestCase {
  let controllerUnderTest = Controller()
  
  override func setUp() {
    XCTAssertNotNil(controllerUnderTest, "controllerUnderTest is nil, and should not be for this test. See line \(#line) \n")
  }
  
  override func tearDown() {
    resetAllValues()
  }
  
  
  // MARK: Helper Methods
  /**
   Sets all the values of `controllerUnderTest` to `0`
   */
  func resetAllValues() {
    controllerUnderTest.emulatingButtonFlags = CInt(0)
    controllerUnderTest.lastButtonFlags = CInt(0)
    
    controllerUnderTest.lastLeftStickX = CShort(0)
    controllerUnderTest.lastLeftStickY = CShort(0)
    controllerUnderTest.lastRightStickX = CShort(0)
    controllerUnderTest.lastRightStickY = CShort(0)
    
    controllerUnderTest.lastLeftTrigger = CChar(0)
    controllerUnderTest.lastRightTrigger = CChar(0)
  }
  
  /**
   Displays "*name* failed to set CInt correctly." Shows expected and actual, as well as failure line.
   
   - parameter name:     The property being tested
   - parameter expected: The expected value for the property
   - parameter actual:   The actual value for the property
   
   - returns: A string with the failure in it formatted to stated actual, expected, and the failure line.
   */
  func displayCIntFailure(name: String, expected: CInt, actual: CInt) -> String {
    return "\(name) failed to set CInt correctly \n. Expected: \(expected)\n. Actual: \(actual) \n. See line \(#line) \n"
  }
  
  /**
   Displays "*name* failed to set CShort correctly." Shows expected and actual, as well as failure line.
   
   - parameter name:     The property being tested
   - parameter expected: The expected value for the property
   - parameter actual:   The actual value for the property
   
   - returns: A string with the failure in it formatted to state the actual, expected, and the failure line.
   */
  func displayCShortFailure(name: String, expected: CShort, actual: CShort) -> String {
    return "\(name) failed to set CShort correctly \n. Expected: \(expected)\n. Actual: \(actual) \n. See line \(#line) \n"
  }
  
  
  // MARK: Tests
  /**
   Asserts that the `emulatingButtonFlags` is of type `CInt` and can be set and gotten from properly
   */
  func test_Assert_emulatingButtonFlags_Sets_To_CInt() {
    // Assert type hasn't changed
    XCTAssertTrue(controllerUnderTest.emulatingButtonFlags.dynamicType == CInt.self, "Expected emulatingButtonFlags to be of type CInt. See line \(#line) \n")
    
    // Assert value is assigned properly.
    let expected = CInt(1)
    controllerUnderTest.emulatingButtonFlags = expected
    XCTAssertTrue(controllerUnderTest.emulatingButtonFlags == expected, displayCIntFailure("emulatingButtonFlags", expected: expected, actual: controllerUnderTest.emulatingButtonFlags))
  }
  
  /**
   Asserts that the `lastButtonFlags` is of type `CInt` and can be set and gotten from properly
   */
  func test_Assert_lastButtonFlags_Sets_To_CInt() {
    // Assert type hasn't changed
    XCTAssertTrue(controllerUnderTest.lastButtonFlags.dynamicType == CInt.self, "Expected lastButtonFlags to be of type CInt. See line \(#line) \n")
    
    // Assert value is assigned properly.
    let expected = CInt(1)
    controllerUnderTest.lastButtonFlags = expected
    XCTAssertTrue(controllerUnderTest.lastButtonFlags == expected, displayCIntFailure("lastButtonFlags", expected: expected, actual: controllerUnderTest.lastButtonFlags))
  }
  
  /**
   Asserts that the `lastLeftStickX` is of type `CShort` and can be set and gotten from properly
   */
  func test_Assert_lastLeftSickX_Sets_To_CShort() {
    // Assert type hasn't changed
    XCTAssertTrue(controllerUnderTest.lastLeftStickX.dynamicType == CShort.self, "Expected lastLeftStickX to be of type CShort. See line \(#line) \n")
    
    // Assert value is assigned properly.
    let expected = CShort(1)
    controllerUnderTest.lastLeftStickX = expected
    XCTAssertTrue(controllerUnderTest.lastLeftStickX == expected, displayCShortFailure("lastLeftStickX", expected: expected, actual: controllerUnderTest.lastLeftStickX))
  }
  
  /**
   Asserts that lastLeftStickY` is of type `CShort` and can be set and gotten from properly
   */
  func test_Assert_lastLeftSitckY_Sets_To_CShort() {
    // Assert type hasn't changed
    XCTAssertTrue(controllerUnderTest.lastLeftStickY.dynamicType == CShort.self, "Expected lastLeftStickY to be of type CShort. See line \(#line) \n")
    
    // Assert value is assigned properly.
    let expected = CShort(1)
    controllerUnderTest.lastLeftStickY = expected
    XCTAssertTrue(controllerUnderTest.lastLeftStickY == expected, displayCShortFailure("lastLeftStickY", expected: expected, actual: controllerUnderTest.lastLeftStickY))

  }
}
