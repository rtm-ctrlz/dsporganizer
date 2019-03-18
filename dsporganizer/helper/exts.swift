//
//  exts.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation
extension NSTextCheckingResult {
    func toNumber(of: String) -> NSNumber {
        return NumberFormatter().number(from: String(of[Range(self.range, in: of)!]))!
    }
    func toCGFloat(of: String) -> CGFloat {
        return CGFloat(truncating: self.toNumber(of: of));
    }
    func toUInt32(of: String) -> UInt32 {
        return UInt32(truncating: self.toNumber(of: of));
    }
}
