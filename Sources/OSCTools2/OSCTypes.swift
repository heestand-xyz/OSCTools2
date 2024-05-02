//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-02-10.
//

import Foundation
import CoreGraphics
import OSCKit

public protocol OSCType {
    static func convert(value: Any) -> Self
}

extension Bool: OSCType {
    public static func convert(value: Any) -> Bool {
        if let bool: Bool = value as? Bool {
            return bool
        } else if let int: Int = value as? Int {
            return int > 0
        } else if let int: Int32 = value as? Int32 {
            return int > 0
        } else if let int: Int64 = value as? Int64 {
            return int > 0
        } else if let float: Float = value as? Float {
            return float > 0.0
        } else if let cgFloat: CGFloat = value as? CGFloat {
            return cgFloat > 0.0
        } else if let double: Double = value as? Double {
            return double > 0.0
        } else if let string: String = value as? String {
            return ["true", "True", "YES", "yes", "1"].contains(string)
        } else if let array: [Any] = value as? [Any],
                  let arrayValue: Any = array.first {
            return convert(value: arrayValue)
        } else {
            return false
        }
    }
}

extension Int: OSCType {
    public static func convert(value: Any) -> Int {
        if let bool: Bool = value as? Bool {
            return bool ? 1 : 0
        } else if let int: Int = value as? Int {
            return int
        } else if let int: Int32 = value as? Int32 {
            return Int(int)
        } else if let int: Int64 = value as? Int64 {
            return Int(int)
        } else if let float: Float = value as? Float {
            return Int(float)
        } else if let cgFloat: CGFloat = value as? CGFloat {
            return Int(cgFloat)
        } else if let double: Double = value as? Double {
            return Int(double)
        } else if let string: String = value as? String {
            return Int(string) ?? 0
        } else if let array: [Any] = value as? [Any],
                  let arrayValue: Any = array.first {
            return convert(value: arrayValue)
        } else {
            return 0
        }
    }
}

extension CGFloat: OSCType {
    public static func convert(value: Any) -> CGFloat {
        if let bool: Bool = value as? Bool {
            return bool ? 1.0 : 0.0
        } else if let int: Int = value as? Int {
            return CGFloat(int)
        } else if let int: Int32 = value as? Int32 {
            return CGFloat(int)
        } else if let int: Int64 = value as? Int64 {
            return CGFloat(int)
        } else if let float: Float = value as? Float {
            return CGFloat(float)
        } else if let cgFloat: CGFloat = value as? CGFloat {
            return cgFloat
        } else if let double: Double = value as? Double {
            return CGFloat(double)
        } else if let string: String = value as? String {
            return CGFloat(Double(string) ?? 0.0)
        } else if let array: [Any] = value as? [Any],
                  let arrayValue: Any = array.first {
            return convert(value: arrayValue)
        } else {
            return 0.0
        }
    }
}

extension String: OSCType {
    public static func convert(value: Any) -> String {
        String(describing: value)
    }
}
