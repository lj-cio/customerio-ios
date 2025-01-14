import Foundation

/**
 Convert between Swift structs and JSON strings and vice-versa.

 Note: When writing tests to check that JSON is equal to other JSON, you need to
 compare the 2 by it's decoded Object, not `Data` or `String` value of the JSON.
 ```
 let expectedJsonBody = jsonAdapter.toJson(expectedObject)

 /// this will fail because the JSON keys sort order is random, not sorted.
 XCAssertEqual(expectedJsonBody, actualJsonBody)
 ```
 An easy fix for this is set `outputFormatting = .sortedKeys` on `JSONEncoder` but
 that is only available >= iOS 11. I don't like having tests that pass or fail depending
 on what iOS version we are testing against so having our CI tests only run on >= iOS 11
 is not a good solution there.

 Instead, you will just need to transition your JSON back into an object and compare
 the objects:
 ```
 let expectedObject: Foo = ...
 let actualObject: Foo = jsonAdapter.fromJson(jsonData!)!

 /// this compared values of the objects so it will pass.
 XCAssertEqual(expectedObject, actualObject)
 ```
 */
// sourcery: InjectRegister = "JsonAdapter"
public class JsonAdapter {
    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private let log: Logger

    init(log: Logger) {
        self.log = log
    }

    /**
     Returns optional to be more convenient then try/catch all over the code base.

     It *should* be rare to have an issue with encoding and decoding JSON because the Customer.io API
     response formats are consistent and input data from the SDK functions are tied to a certain data
     type (if struct wants an Int, you can only pass an Int).

     The negative to this method is that we don't get to capture the `Error` to debug it if we don't
     expect to get an error. If we need this functionality, perhaps we should create a 2nd set of
     methods to this class that `throw` so you choose which function to use?
     */
    public func fromJson<T: Decodable>(_ json: Data, decoder override: JSONDecoder? = nil) -> T? {
        var errorStringToLog: String?

        do {
            let value = try (override ?? decoder).decode(T.self, from: json)
            return value
        } catch DecodingError.keyNotFound(let key, let context) {
            errorStringToLog = """
            Decode key not found. Key: \(key),
            Json path: \(context.codingPath), json: \(json.string ?? "(error getting json string)")
            """
        } catch DecodingError.valueNotFound(let type, let context) {
            errorStringToLog = """
            Decode non-optional value not found. Value: \(type), Json path: \(context.codingPath), json: \(json
                .string ?? "(error getting json string)")
            """
        } catch DecodingError.typeMismatch(let type, let context) {
            errorStringToLog = """
            Decode type did not match payload. Type: \(type), Json path: \(context.codingPath), json: \(json
                .string ?? "(error getting json string)")
            """
        } catch DecodingError.dataCorrupted(let context) {
            errorStringToLog = """
            Decode data corrupted. Json path: \(context.codingPath), json: \(json
                .string ?? "(error getting json string)")
            """
        } catch {
            errorStringToLog = """
            Generic decide error. \(error.localizedDescription), json: \(json.string ?? "(error getting json string)")
            """
        }

        if let errorStringToLog = errorStringToLog {
            log.error(errorStringToLog)
        }

        return nil
    }

    public func toJson<T: Encodable>(_ obj: T, encoder override: JSONEncoder? = nil) -> Data? {
        do {
            let value = try (override ?? encoder).encode(obj)
            return value
        } catch EncodingError.invalidValue(let value, let context) {
            self.log
                .error("Encoding could not encode value. \(value), Json path: \(context.codingPath), object: \(obj)")
        } catch {
            log.error("Generic encode error. \(error.localizedDescription), object: \(obj)")
        }

        return nil
    }
}
