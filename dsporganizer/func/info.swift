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
    var curDescr:[String: String] = [:]
    var curMainId: String = ""
    for screen in NSScreen.screens {
        let deviceDescription = screen.deviceDescription
        let screenId = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]!
        let cgScreenId = CGDirectDisplayID(truncating: NSNumber(value: screenId as! Int))
        let mode = CGDisplayCopyDisplayMode(cgScreenId)!
        
        print("Screen Id:",screenId)
        
        let size = deviceDescription[NSDeviceDescriptionKey.size]! as! NSSize;
        print("Size: ", Int(size.width),"x",Int(size.height), separator: "")
        
        print("Global Position: ", Int(screen.frame.origin.x),",",Int(screen.frame.origin.y)," ", Int(screen.frame.origin.x + screen.frame.width),",",Int(screen.frame.origin.y+screen.frame.height), separator: "")
        
        print("Color Space:", deviceDescription[NSDeviceDescriptionKey.colorSpaceName] as! String)
        
        print("Resolution:", NSStringFromSize(deviceDescription[NSDeviceDescriptionKey.resolution] as! NSSize))
        
        print("Refresh Rate:", mode.refreshRate)
        
        if (CGDisplayUsesOpenGLAcceleration(cgScreenId)>0) {
            print("Uses Quartz Extreme: YES")
        } else {
            print("Uses Quartz Extreme: NO")
        }
        print("");
        if (screen.frame.origin.x == 0 && screen.frame.origin.y==0) {
            curMainId = String(cgScreenId)
        } else {
            curDescr[String(cgScreenId)] = String(cgScreenId) + ":" + String(format: "%.0f", screen.frame.origin.x) + "," + String(format: "%.0f", screen.frame.origin.y)
        }
    }
    if (curDescr.count < 0) {
        print("No screens found.")
        exit(EXIT_FAILURE)
    }
    print("Current setup for positioning (call example):")
    if (curDescr.count == 0) {
        print("  Only one screen found, positioning need 2+ screens.")
        exit(EXIT_SUCCESS)
    }
    if (curMainId == "") {
        curMainId = curDescr.first!.key
        curDescr[curMainId] = nil
    }
    print("  $ "+prog+" -m "+curMainId+" -p '"+curDescr.map({return $0.value}).joined(separator: ",")+"'")
}
