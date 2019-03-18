//
//  current.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation
import AppKit

func displayCurrentCmd() {
    var curDescr:[String: String] = [:]
    var curMainId: String = ""
    for screen in NSScreen.screens {
        let cgScreenId = CGDirectDisplayID(truncating: NSNumber(value: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]!) as! Int))
        if (screen.frame.origin.x == 0 && screen.frame.origin.y==0) {
            curMainId = String(cgScreenId)
        } else {
            curDescr[String(cgScreenId)] = String(cgScreenId) + ":" + String(format: "%.0f", screen.frame.origin.x) + "," + String(format: "%.0f", screen.frame.origin.y)
        }
    }
    if (curDescr.count < 0) {
        return
    }
    if (curDescr.count == 0) {
        return
    }
    if (curMainId == "") {
        curMainId = curDescr.first!.key
        curDescr[curMainId] = nil
    }
    print("Current setup positioning (call example):",
          " $ "+prog+" -m "+curMainId+" -p '"+curDescr.map({return $0.value}).joined(separator: ",")+"'",
          separator: "\n"
    )
    
}
