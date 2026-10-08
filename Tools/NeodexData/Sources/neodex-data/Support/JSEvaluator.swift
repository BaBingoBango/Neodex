import Foundation
import JavaScriptCore

/// Evaluates Pokémon Showdown's data files with JavaScriptCore and hands back plain JSON.
///
/// The client ships prebuilt CommonJS modules (`exports.BattlePokedex = {…};`) and the server
/// repository holds TypeScript modules (`export const Natures: SomeType = {…};`). Both are
/// JavaScript object literals once the surrounding declaration is stripped.
enum JSEvaluator {
    enum EvaluationError: Error, LocalizedError {
        case javaScript(String)
        case missingExport(String)
        case unsupportedModule

        var errorDescription: String? {
            switch self {
            case .javaScript(let message): "JavaScript error: \(message)"
            case .missingExport(let name): "The module did not define exports.\(name)"
            case .unsupportedModule: "Could not find an object literal export in the TypeScript module"
            }
        }
    }

    /// Returns the JSON for `exports.<exportName>` of a Showdown client module.
    static func clientModuleJSON(_ source: String, exportName: String) throws -> Data {
        let context = try makeContext()
        context.evaluateScript("var exports = {}; var module = { exports: exports };")
        context.evaluateScript(source)
        if let exception = context.exception { throw EvaluationError.javaScript(exception.toString()) }
        guard let result = context.evaluateScript("JSON.stringify(exports[\(quoted(exportName))])"),
              !result.isUndefined, let json = result.toString(), json != "undefined" else {
            throw EvaluationError.missingExport(exportName)
        }
        return Data(json.utf8)
    }

    /// Returns the JSON for the single `export const X: Type = {…}` in a Showdown TypeScript data module.
    static func typeScriptModuleJSON(_ source: String) throws -> Data {
        guard let declaration = source.range(of: #"export const \w+\s*(:[^=]*)?=\s*"#, options: .regularExpression) else {
            throw EvaluationError.unsupportedModule
        }
        var body = String(source[declaration.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasSuffix(";") { body.removeLast() }
        // Strip trailing `export` statements or comments that sometimes follow the object.
        if let end = body.range(of: "\n};", options: .backwards) {
            body = String(body[..<end.lowerBound]) + "\n}"
        } else if let end = body.range(of: "\n}", options: .backwards) {
            body = String(body[..<end.upperBound])
        }
        let context = try makeContext()
        context.evaluateScript("var __module = (\(body));")
        if let exception = context.exception { throw EvaluationError.javaScript(exception.toString()) }
        guard let result = context.evaluateScript("JSON.stringify(__module)"), let json = result.toString(), json != "undefined" else {
            throw EvaluationError.unsupportedModule
        }
        return Data(json.utf8)
    }

    private static func makeContext() throws -> JSContext {
        guard let context = JSContext() else { throw EvaluationError.javaScript("Could not create a JSContext") }
        context.exceptionHandler = { context, exception in
            context?.exception = exception
        }
        return context
    }

    private static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
