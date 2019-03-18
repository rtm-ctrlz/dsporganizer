//
//  main.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 15.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation

var longopts: [option] = []
var ProgOptsShort: String = ""
for (_, item) in ProgOpts {
    longopts.append(option(name: item.long, has_arg: item.has_arg, flag: nil, val: item.short))
    ProgOptsShort.append(Character(UnicodeScalar(UInt32(item.short))!))
    if (item.has_arg != no_argument) {
        if (item.has_arg == required_argument) {
            ProgOptsShort.append(":")
        } else if (item.has_arg == optional_argument) {
            ProgOptsShort.append("::")
        }
    }
}
longopts.append(option());
var posMain:String? = nil
var posDecr: String? = nil

// getting arguments
opterr = 0
while case let option = getopt_long(CommandLine.argc, CommandLine.unsafeArgv, getOptsShort(), longopts, nil), option != -1 {
    switch (option) {
    case ProgOpts[ProgOptsKey.help]!.short:
        displayHelp()
        exit(EXIT_SUCCESS)
    case ProgOpts[ProgOptsKey.info]!.short:
        displayInfo()
        exit(EXIT_SUCCESS)
    case ProgOpts[ProgOptsKey.screens]!.short:
        displayScreens()
        exit(EXIT_SUCCESS)
    case ProgOpts[ProgOptsKey.main]!.short:
        posMain = String(cString: optarg)
    case ProgOpts[ProgOptsKey.position]!.short:
        posDecr = String(cString: optarg)
    default:
        continue
    }
}

// should we do positioning?
if ((posMain != nil) || (posDecr != nil)) {
    if (posMain == nil && posDecr == nil) {
        print("Position displays: arguments 'main' and 'position' missing.")
    } else if (posDecr == nil) {
        print("Position displays: argument 'position' missing.")
    } else if (posMain == nil) {
        print("Position displays: argument 'main' missing.")
    } else {
        positionDisplays(posMain!, posDecr!)
        exit(EXIT_SUCCESS)
    }
    exit(EXIT_FAILURE)
}

// display help
displayHelp()
