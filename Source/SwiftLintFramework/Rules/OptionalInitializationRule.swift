//
// The MIT License (MIT)
//
// Copyright (c) 2016 Sonos, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import SourceKittenFramework

extension File {
    private func violatingOptionalInitialization() -> [NSRange] {
        return matchPattern("(var)((.(?!\\s(var|let)\\s))*?):((.(?!\\s(var|let)\\s))*?)\\?"
            + "(\\s*)(=)(\\s*)(nil)(\\s*)$",
                            excludingSyntaxKinds: SyntaxKind.commentAndStringKinds())
    }
}

public struct OptionalInitializationRule: OptInRule, CorrectableRule, ConfigurationProviderRule {
    public var configuration = SeverityConfiguration(.Warning)
    public init() {}
    public static let description = RuleDescription(
        identifier: "optional_initialization",
        name: "Optional Initialization",
        description: "Optionals do not need to be initialized to nil",
        nonTriggeringExamples: [
            "var obj: Bool? = nil, obj1: Bool?",
            "var boolean0: Bool? = nil, boolean1: Bool?",
            "var boolean: Bool? /**this is a comment*/= nil",
            "var boolean: /**this is a comment*/Bool? = nil"
        ],
        triggeringExamples: [
            "var image: UIImage? = nil",
            "var onCallback: ((UIImage?) -> Void)? = nil",
            "var onCallback: ((NSData) -> Void)?\n= nil"
        ],
        corrections: [
            "var image: UIImage? = nil": "var image: UIImage?",
            "var variable: ((UIImage?) -> Void)? = nil": "var variable: ((UIImage?) -> Void)?  ",
            "var onCallback: ((NSData) -> Void)?\n= nil":"var onCallback: ((NSData) -> Void)?\n "
        ]
    )

    public func validateFile(file: File) -> [StyleViolation] {
        return file.violatingOptionalInitialization().map {
            StyleViolation(ruleDescription: self.dynamicType.description,
                severity: configuration.severity,
                location: Location(file: file, characterOffset: $0.location))
        }
    }

    public func correctFile(file: File) -> [Correction] {
        let adjustedRanges = file.ruleEnabledViolatingRanges(
            file.violatingOptionalInitialization(),
            forRule: self
        )
        
        if adjustedRanges.isEmpty {
            return []
        }
        
        var correctedContents = file.contents
        for range in adjustedRanges {
            // Leave the spaces but delete "=" and "nil" (replacing those with spaces as well)
            // This is to prevent changes the ranges of violating lines
            if let regex = try? NSRegularExpression(pattern: "(\\s*)=(\\s*)nil",
                                                    options: .CaseInsensitive) {
                correctedContents = regex.stringByReplacingMatchesInString(
                    correctedContents, options: [], range: range, withTemplate: "$1 $2   ")
                }
        }
        file.write(correctedContents)
        return adjustedRanges.map {
            Correction(ruleDescription: self.dynamicType.description,
                location: Location(file: file, characterOffset: $0.location))
        }
    }

}
