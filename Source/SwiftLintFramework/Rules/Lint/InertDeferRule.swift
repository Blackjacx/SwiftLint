import Foundation
import SourceKittenFramework

public struct InertDeferRule: ConfigurationProviderRule, AutomaticTestableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "inert_defer",
        name: "Inert Defer",
        description: "If defer is at the end of its parent scope, it will be executed right where it is anyway.",
        kind: .lint,
        nonTriggeringExamples: [
            """
            func example3() {
                defer { /* deferred code */ }

                print("other code")
            }
            """,
            """
            func example4() {
                if condition {
                    defer { /* deferred code */ }
                    print("other code")
                }
            }
            """
        ],
        triggeringExamples: [
            """
            func example0() {
                ↓defer { /* deferred code */ }
            }
            """,
            """
            func example1() {
                ↓defer { /* deferred code */ }
                // comment
            }
            """,
            """
            func example2() {
                if condition {
                    ↓defer { /* deferred code */ }
                    // comment
                }
            }
            """
        ]
    )

    public func validate(file: File) -> [StyleViolation] {
        let defers = file.match(pattern: "defer\\s*\\{", with: [.keyword])

        return defers.compactMap { range -> StyleViolation? in
            let contents = file.contents.bridge()
            guard let byteRange = contents.NSRangeToByteRange(start: range.location, length: range.length),
                case let kinds = file.structure.kinds(forByteOffset: byteRange.upperBound, in: file.structureDictionary),
                let brace = kinds.enumerated().lazy.reversed().first(where: isBrace),
                brace.offset > kinds.startIndex,
                case let outerKindIndex = kinds.index(before: brace.offset),
                case let outerKind = kinds[outerKindIndex],
                case let braceEnd = brace.element.byteRange.upperBound,
                case let tokensRange = NSRange(location: braceEnd, length: outerKind.byteRange.upperBound - braceEnd),
                case let tokens = file.syntaxMap.tokens(inByteRange: tokensRange),
                !tokens.contains(where: isNotComment) else {
                    return nil
            }

            return StyleViolation(ruleDescription: type(of: self).description,
                                  severity: configuration.severity,
                                  location: Location(file: file, characterOffset: range.location))
        }
    }
}

private func isBrace(offset: Int, element: (kind: String, byteRange: NSRange)) -> Bool {
    return StatementKind(rawValue: element.kind) == .brace
}

private func isNotComment(token: SyntaxToken) -> Bool {
    guard let kind = SyntaxKind(rawValue: token.type) else {
        return false
    }

    return !SyntaxKind.commentKinds.contains(kind)
}
