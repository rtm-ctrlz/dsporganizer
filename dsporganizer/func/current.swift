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
    guard let displays = try? currentDisplays(), displays.count > 1 else {
        return
    }
    // if main screen not found pick first screen as main
    let main = (displays.first(where: { $0.isMain }) ?? displays[0]).id
    var positions: [CGDirectDisplayID: CGPoint] = [:]
    for display in displays {
        // CGDisplayBounds: the coordinate system --position works in
        positions[display.id] = display.bounds.origin
    }
    print("Current positioning setup (call example):",
          " $ " + positionCommand(main: main, positions: positions),
          separator: "\n"
    )
}
