//
//  help.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation

func displayHelp() {
    print(
        "Use "+prog+" to either get information about your screens",
        "or for setting the main screen (the screen with the menu bar).",
        
        "Usage: "+prog,
        "\t"+ProgOpts.map({return $0.value.help}).joined(separator: "\n\t"),
        "",
        "NOTE: Global Position {0, 0} coordinate (as shown under --info)",
        "      is the lower left corner of the main screen axes:",
        "        - XAxis: from right (0px) to left (Npx)",
        "        - YAxis: from bottom (0px) to up (Npx)",
        "",
        "Positioning screens: args 'main' and 'position' are reqiered.",
        "  Main screen will have position {0,0}.",
        "",
        "  Position arg format:",
        "\tformat: [<screenId-1>:<X-pos-1>x<Y-pos-1>,]<screenId-2>:<X-pos-2>x<Y-pos-2>",
        "\texamples:",
        "\t\t112233:0x1200",
        "\t\t112233:0x1200,445566:0x2280",
        "",
        "  Complete example:",
        "    Screens:",
        "     main screen (id: 123, size: 1920x1200)",
        "     second screen(id: 456, size: 1920x1080)",
        "    Positioning:",
        "     1) second screen to the right of main:",
        "        $ "+prog+"-m 123 -p '456:1920x0",
        "     2) second screen ontop of main:",
        "        $ "+prog+"-m 123 -p '456:0x1200'",
        separator: "\n"
    )
}
