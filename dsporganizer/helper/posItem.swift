//
//  posItem.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation

struct posItem {
    var position: NSPoint = NSMakePoint(0, 0);
    var found: Bool = false;
    init(_ pos: NSPoint) {
        self.position = pos;
    }
}
