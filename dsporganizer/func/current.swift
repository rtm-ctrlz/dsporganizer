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
    if (NSScreen.screens.count == 1) {
        return
    }
    
    var curDescr:[String: String] = [:]
    var curMainId: String = ""
    for screen in NSScreen.screens {
        let cgScreenId = CGDirectDisplayID(truncating: NSNumber(value: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]!) as! Int))
        if (CGDisplayIsMain(cgScreenId) != 0) {
            curMainId = String(cgScreenId)
        } else {
            // CGDisplayBounds: the coordinate system --position works in
            let bounds = CGDisplayBounds(cgScreenId)
            curDescr[String(cgScreenId)] = String(cgScreenId) + ":" + String(Int(bounds.origin.x)) + "x" + String(Int(bounds.origin.y))
        }
    }
    // is it possible?
    if (curDescr.count < 0) {
        return
    }
    // if main screen not found pick first screen as main
    if (curMainId == "") {
        curMainId = curDescr.first!.key
        curDescr[curMainId] = nil
    }
    // one '-p' per screen, ordered by screen id, so the line is stable between runs
    let posArgs = curDescr.keys
        .sorted(by: { (UInt32($0) ?? 0) < (UInt32($1) ?? 0) })
        .map({ return "-p " + curDescr[$0]! })
        .joined(separator: " ")
    print("Current positioning setup (call example):",
          " $ " + prog + " -m " + curMainId + " " + posArgs,
          separator: "\n"
    )
    
}
