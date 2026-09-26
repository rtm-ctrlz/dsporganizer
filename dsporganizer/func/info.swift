//
//  info.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation
import AppKit

func displayInfo() {
    for screen in NSScreen.screens {
        let deviceDescription = screen.deviceDescription
        let screenId = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]!
        let cgScreenId = CGDirectDisplayID(truncating: NSNumber(value: screenId as! Int))
        let mode = CGDisplayCopyDisplayMode(cgScreenId)!
        
        print("Screen Id:",screenId)
        
        let size = deviceDescription[NSDeviceDescriptionKey.size]! as! NSSize;
        print("Size: ", Int(size.width),"x",Int(size.height), separator: "")
        
        // CGDisplayBounds, not NSScreen.frame: these are the coordinates
        // CGConfigureDisplayOrigin (and therefore --position) works with
        let bounds = CGDisplayBounds(cgScreenId)
        let tlX = Int(bounds.origin.x)
        let tlY = Int(bounds.origin.y)
        let brX = Int(bounds.origin.x + bounds.width)
        let brY = Int(bounds.origin.y + bounds.height)
        print("Global Position:",
              "  top-left (origin): X=\(tlX), Y=\(tlY)",
              "  bottom-right     : X=\(brX), Y=\(brY)",
              "  position         : " + ((CGDisplayIsMain(cgScreenId) != 0)
                                          ? "-m \(cgScreenId)"
                                          : "-p \(cgScreenId):\(tlX)x\(tlY)"),
              separator: "\n"
        )
        
        print("Color Space:", deviceDescription[NSDeviceDescriptionKey.colorSpaceName] as! String)
        
        print("Resolution:", NSStringFromSize(deviceDescription[NSDeviceDescriptionKey.resolution] as! NSSize))
        
        print("Refresh Rate:", mode.refreshRate)
        
        if (CGDisplayUsesOpenGLAcceleration(cgScreenId)>0) {
            print("Uses Quartz Extreme: YES")
        } else {
            print("Uses Quartz Extreme: NO")
        }
        print("");
    }
    displayCurrentCmd()
}
