//
//  position.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation

func positionDisplays(_ posMain: String, _ posDecr: String) {
    if (Int(posMain)==nil) {
        print("PD: invalid main value -", posMain)
        exit(EXIT_FAILURE)
    }
    let iMain = UInt32(posMain)!
    let range = NSRange(location: 0, length: posDecr.utf16.count)
    
    var re = try! NSRegularExpression(pattern: "^(\\d+:-?\\d+x-?\\d+,+)*(\\d+:-?\\d+x-?\\d+)$", options: [NSRegularExpression.Options.caseInsensitive,NSRegularExpression.Options.anchorsMatchLines])
    let test = re.matches(in: posDecr, options: [], range: range);
    if (test.count != 1) {
        print("PD: 'position' - wrong format")
        exit(EXIT_FAILURE)
    }
    re = try! NSRegularExpression(pattern: "\\d+:-?\\d+x-?\\d+", options: [NSRegularExpression.Options.caseInsensitive])
    
    var posDict: [UInt32: posItem] = [iMain: posItem(NSMakePoint(CGFloat(0), CGFloat(0)))]
    
    let reNum = try! NSRegularExpression(pattern: "-?\\d+", options: [])
    for item in re.matches(in: posDecr, options: [], range: range).map({
        String(posDecr[Range($0.range, in: posDecr)!])
    }) {
        let itemMatches = reNum.matches(in: item, options: [], range: NSRange(location: 0, length: item.utf16.count))
        let itemKey = itemMatches[0].toUInt32(of: item)
        
        if (posDict.keys.contains(itemKey)) {
            print("PD: duplicate screenId (",itemKey,")in 'position'", separator: "")
            exit(EXIT_FAILURE)
        }
        if (posDict.count >= MAX_DISPLAYS-1) {
            print("PD: MAX_DISPLAYS (", MAX_DISPLAYS ,") limit reached", separator: "")
            exit(EXIT_FAILURE)
        }
        posDict[itemKey] = posItem(NSMakePoint(itemMatches[1].toCGFloat(of: item), itemMatches[2].toCGFloat(of: item)))
    }
    
    let Displays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: MAX_DISPLAYS)
    let DCount = UnsafeMutablePointer<CGDisplayCount>.allocate(capacity: MAX_DISPLAYS);
    let err = CGGetActiveDisplayList(UInt32(MAX_DISPLAYS), Displays, DCount)
    if (err != CGError.success) {
        print("Error: cannot get displays:", err.rawValue);
        exit(EXIT_FAILURE)
    }
    
    
    if (Int(DCount.pointee)==1) {
        print("PD: only one display found!")
        exit(EXIT_FAILURE)
    }
    
    let buf = UnsafeMutableBufferPointer(start: Displays, count: Int(DCount.pointee))
    for (_, screenId) in buf.enumerated() {
        if (posDict.keys.contains(screenId)) {
            posDict[screenId]!.found = true;
        } else {
            print("PD: found undefined screen (",screenId,")")
            exit(EXIT_FAILURE)
        }
    }
    let missingPos = posDict.filter({return !$1.found}).keys;
    if (missingPos.count>0){
        for missingKey in missingPos {
            print("PD: screen (",missingKey,") not found, skipping",separator: "")
            posDict.removeValue(forKey: missingKey)
        }
    }
    if (!posDict.keys.contains(iMain)) {
        print("PD: missing main screen (",iMain,")",separator:"")
        exit(EXIT_FAILURE);
    }
    if (posDict.count==1) {
        exit(EXIT_FAILURE);
    }
    
    let config = UnsafeMutablePointer<CGDisplayConfigRef?>.allocate(capacity: MAX_DISPLAYS)
    CGBeginDisplayConfiguration(config)
    
    for (screenId, dsp) in posDict {
        CGConfigureDisplayOrigin(config.pointee, screenId, Int32(dsp.position.x), Int32(dsp.position.y))
    }
    
    CGCompleteDisplayConfiguration(config.pointee, CGConfigureOption.forSession)
    Displays.deinitialize(count:MAX_DISPLAYS)
    Displays.deallocate()
}
