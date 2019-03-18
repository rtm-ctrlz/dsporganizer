//
//  opts.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation
import AppKit

enum ProgOptsKey: String {
    case help =     "help"
    case info =     "info"
    case screens =  "screens"
    case main =     "main"
    case position = "position"
}


var ProgOpts: Dictionary<ProgOptsKey, Opt> = [
    ProgOptsKey.help:     Opt("h", ProgOptsKey.help, descrition: "shows the help text"),
    ProgOptsKey.info:     Opt("i", ProgOptsKey.info, descrition: "shows information about the connected screens"),
    ProgOptsKey.screens:  Opt("s", ProgOptsKey.screens,  true, descrition: "returns only the screen IDs for the connected screens"),
    ProgOptsKey.main:     Opt("m", ProgOptsKey.main,     true, descrition: "identify main screen (id)"),
    ProgOptsKey.position: Opt("p", ProgOptsKey.position, true, descrition: "other screen position descriptions")
]


func getOptsShort() -> String {
    var ProgOptsShort: String = "";
    for (_, item) in ProgOpts {
        ProgOptsShort.append(Character(UnicodeScalar(UInt32(item.short))!))
        if (item.has_arg != no_argument) {
            if (item.has_arg == required_argument) {
                ProgOptsShort.append(":")
            } else if (item.has_arg == optional_argument) {
                ProgOptsShort.append("::")
            }
        }
    }
    return ProgOptsShort
}

func optToOption(opt: Opt) -> option {
    return option(name: opt.long, has_arg: opt.has_arg, flag: nil, val: opt.short)
}

func getOptsLong() -> [option] {
    var longopts:[option] = [];
    for (_, opt) in ProgOpts {
        longopts.append(optToOption(opt: opt))
    }
    longopts.append(option());
    return longopts
}
