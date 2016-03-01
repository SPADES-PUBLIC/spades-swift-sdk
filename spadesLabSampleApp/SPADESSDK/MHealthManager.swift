//
//  MHealthManager.swift
//  spadesLabSampleApp
//
//  Created by Stanis Laus Billy on 2/26/16.
//  Copyright © 2016 QMEDIC. All rights reserved.
//

import Foundation

// Supported mHealth sensors for iOS
enum MHealthSensor:String {
    case STEPS = "STEPS"
    case PROMIS = "PROMIS"
    case ANNOTATION = "ANNOTATION"
    case GPS = "GPS"
}

class MHealthUtils {
    
    static let DEVICE_TYPE = "iPhone"
    static let OS_INFO = "iOSx"+UIDevice.currentDevice().systemVersion.stringByReplacingOccurrencesOfString(".", withString: "x")
    
    static let PATTERN_SENSORTYPE_DATATYPE_VERSIONINFO = "[a-zA-Z0-9-]+"
    static let PATTERN_SENSOR_ID = "[a-zA-Z0-9-]+"
    static let PATTERN_YEAR = "2\\d{3}"
    static let PATTERN_MONTH = "[0-1]\\d"
    static let PATTERN_DAY = "[0-3]\\d"
    static let PATTERN_HOUR = "[0-2]\\d"
    static let PATTERN_MINUTE = "[0-5]\\d"
    static let PATTERN_SECOND = "[0-5]\\d"
    static let PATTERN_MILLISECOND = "\\d{3}"
    static let PATTERN_TIMEZONE = "[P/M][0-1]\\d[0-5]\\d"
    static let PATTERN_FILETYPE = "(sensor|annotation|event)"
    
    static let PATTERN_MHEALTH_FILENAME = "(\(PATTERN_SENSORTYPE_DATATYPE_VERSIONINFO))(\\.\(PATTERN_SENSOR_ID))(\\.\(PATTERN_YEAR))(-\(PATTERN_MONTH))(-\(PATTERN_DAY))(-\(PATTERN_HOUR))(-\(PATTERN_MINUTE))(-\(PATTERN_SECOND))(-\(PATTERN_MILLISECOND))(-\(PATTERN_TIMEZONE))(\\.\(PATTERN_FILETYPE))(\\.csv.gz)$"
    
    class func IsValidMHealthFilename(filename:String) -> Bool {
        // sensor file example: "iPhone-STEPS-iOSx9x1.1112223333-STEPS.2016-01-22-19-22-34-310-M0500.sensor.csv.gz"
        // annotation file example: "SelfAnnotation.1112223333-SelfAnnotation.2016-01-22-19-22-34-310-M0500.annotation.csv.gz"
        // event file example: "Battery.1112223333-Battery.2016-01-22-19-22-34-310-M0500.event.csv.gz"
        if let _ = filename.rangeOfString(PATTERN_MHEALTH_FILENAME, options: NSStringCompareOptions.RegularExpressionSearch, range: nil, locale: nil) {
            return true
        } else {
            return false
        }
    }
    
    class func ParseTokenFromMHealthFilename(filename:String, index:Int) -> String {
        // Example:  iPhone-STEPS-iOSx9x1.1112223333-STEPS.2016-01-28-10-30-51-023-M0500.sensor.csv.gz
        if index < 0 || index > 5 {
            return ""
        }
        if !filename.hasSuffix(".csv.gz") {
            return ""
        }
        let tokens = filename.characters.split(".").map(String.init)
        if tokens.count != 6 {
            return ""
        }
        return tokens[index]
    }
    
    class func ParseMHealthType(filename:String) -> String {
        return ParseTokenFromMHealthFilename(filename, index: 3)
    }
    
    class func ParseDataAndSensorInfo(filename:String) -> String {
        return ParseTokenFromMHealthFilename(filename, index: 0)
    }
    
    class func ParseSerialNumber(filename:String) -> String {
        return ParseTokenFromMHealthFilename(filename, index: 1)
    }
    
    class func ParseDate(filename:String) -> String {
        return ParseTokenFromMHealthFilename(filename, index: 2)
    }
    
}