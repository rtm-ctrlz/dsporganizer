//
//  opt.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation


struct Opt {
    var short: Int32
    var long: UnsafePointer<Int8>!
    var has_arg: Int32
    var help: String
    init(_ short: String, _ long: ProgOptsKey, _ has_arg: Bool? = nil, descrition: String = "no descrition") {
        self.short = Int32(short.unicodeScalars.first!.value)
        self.long = UnsafePointer.init(long.rawValue.cString(using: .utf8))
        if (has_arg == nil) {
            self.has_arg = no_argument
        } else if (has_arg!) {
            self.has_arg = required_argument
        } else {
            self.has_arg = optional_argument
        }
        self.help = "-"+short+"|--"+long.rawValue+") "+descrition
    }
}
