//
//  position.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation
import CoreGraphics

func positionDisplays(_ posMain: String, _ posDecr: String) {
    if (Int(posMain)==nil) {
        print("PD: invalid main value -", posMain)
        exit(EXIT_FAILURE)
    }
    let iMain = UInt32(posMain)!
    let range = NSRange(location: 0, length: posDecr.utf16.count)
    
    var re = try! NSRegularExpression(pattern: "^(\\d+:-?\\d+[,x]-?\\d+,+)*(\\d+:-?\\d+[,x]-?\\d+)$", options: [NSRegularExpression.Options.caseInsensitive,NSRegularExpression.Options.anchorsMatchLines])
    let test = re.matches(in: posDecr, options: [], range: range);
    if (test.count != 1) {
        print("PD: 'position' - wrong format")
        exit(EXIT_FAILURE)
    }
    re = try! NSRegularExpression(pattern: "\\d+:-?\\d+[,x]-?\\d+", options: [NSRegularExpression.Options.caseInsensitive])
    
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
    
    var positions: [CGDirectDisplayID: CGPoint] = [:]
    for (screenId, dsp) in posDict {
        positions[screenId] = dsp.position
    }
    do {
        for missingKey in try applyDisplayLayout(main: iMain, positions: positions) {
            print("PD: screen (",missingKey,") not found, skipping",separator: "")
        }
    } catch DisplayError.nothingToPosition {
        exit(EXIT_FAILURE)
    } catch {
        print("PD:", error)
        exit(EXIT_FAILURE)
    }
}
