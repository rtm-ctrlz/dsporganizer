# dsporganizer
Cli utility for position external screen in macOS


# The goal
Provide a way to position external screens with with an accuracy of one pixel.
Positioning of external displays with System Preferences could be done, but with a huge steps (ex. 1px move in prefs. gives 16px move of screens) and edge snapping, for most users it's OK, but when you need something beyond this - there is no options.


# Solution
CLI utility that uses CoreGraphics to place screens exactly as you want.


# Side effects
Since you can make screens to overlap or make a gap between then - resulting positions of screens may be not exactly as you expecting, so use `--info`

# Usage
## Info
**`-i | --info`**

Display available screens with properties
```shell
$ dsporganizer --info

Screen Id: 69733378
Size: 1920x1200
Global Position: 0,0 1920,1200
Color Space: NSCalibratedRGBColorSpace
Resolution: {144, 144}
Refresh Rate: 0.0
Uses Quartz Extreme: YES

Screen Id: 637697159
Size: 3840x1080
Global Position: 0,1200 3840,2280
Color Space: NSCalibratedRGBColorSpace
Resolution: {72, 72}
Refresh Rate: 0.0
Uses Quartz Extreme: YES

Current setup positioning (call example):
 $ dsporganizer -m 69733378 -p '637697159:0,1200'
```

## Screens list
**`-s | --screens`**
```shell
$ dsporganizer --screens

69733378
637697159
```

## Positioning screens
### Main screen
All positioning is made relativly to one (main) screen, there is no any difference which screen you choose as main. Main screen will always have position with coords `0x0`.

### Arguments
To position screens arguments `-m | --main` (id of main screen) and `-p | --position` (positions definition) are required.

#### Argument values

##### Main screen
To get IDs of screens use keys `--screens` or `--info`. I suggest to use `--info`, which can tell screen sizes to to determine screens by their dimensions.

###### Positions definition
Postions definition is a string, containing comma-separated list of ids of screens and their positions. 

Examples definitions:
```
// single screen
111223344:1920x1080

// two screens
1234:1920x1080,5678:3840x1080
```

I don't know how to describe this pattern, but in regex terms it will be `\d+:-?\d+x-?\d+` - for a single screen and `/^(\d+:-?\d+x-?\d+,)*\d+:-?\d+x-?\d+$/` - for one or many screens.

# Сompatibility
 ✅ macOS 10.13 Hight Sierra
