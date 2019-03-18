//
//  screens.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation

func displayScreens() {
    let Displays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: MAX_DISPLAYS)
    let DCount = UnsafeMutablePointer<CGDisplayCount>.allocate(capacity: MAX_DISPLAYS);
    let err = CGGetActiveDisplayList(UInt32(MAX_DISPLAYS), Displays, DCount)
    if (err != CGError.success) {
        print("Error: cannot get displays:", err.rawValue);
        exit(EXIT_FAILURE)
    }
    let buf = UnsafeMutableBufferPointer(start: Displays, count: Int(DCount.pointee))
    for value in buf.enumerated() {
        print(value.element)
    }
    
    Displays.deinitialize(count:MAX_DISPLAYS)
    Displays.deallocate()
}
