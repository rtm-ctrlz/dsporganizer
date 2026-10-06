//
//  screens.swift
//  dsporganizer
//
//  Created by Внештатный командир земли on 18.03.2019.
//  Copyright © 2019 Внештатный командир земли. All rights reserved.
//

import Foundation
import CoreGraphics

func displayScreens() {
    do {
        for id in try activeDisplayIDs() {
            print(id)
        }
    } catch {
        print("Error:", error)
        exit(EXIT_FAILURE)
    }
}
