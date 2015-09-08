@testable import MessagePack
import XCTest

func map(count: Int) -> [MessagePackValue : MessagePackValue] {
    var dict = [MessagePackValue : MessagePackValue]()
    for i in 0..<count {
        dict[.Int(numericCast(i))] = .Nil
    }

    return dict
}

func payload(count: Int) -> Data {
    var data = Data()
    for i in 0..<count {
        data += pack(.Int(numericCast(i))) + pack(.Nil)
    }
    
    return data
}

func testPackMap(count: Int, prefix: Data) {
    let packed = pack(.Map(map(count)))

    var generator = packed.generate()
    for expectedByte in prefix {
        guard let byte = generator.next() else {
            XCTFail("Insufficient data")
            preconditionFailure()
        }

        XCTAssertEqual(byte, expectedByte)
    }

    var keys = Set<Int>()
    for _ in 0..<count {
        do {
            let key: Int
            switch try unpack(&generator) {
            case .Int(let value):
                key = numericCast(value) as Int
            case .UInt(let value):
                key = numericCast(value) as Int
            default:
                XCTFail("Expected .Int or .UInt value")
                preconditionFailure()
            }

            XCTAssertFalse(keys.contains(key))
            keys.insert(key)

            if try unpack(&generator) != .Nil {
                XCTFail("Expected .Nil")
            }
        } catch {
            XCTFail("Caught error: \(error)")
        }
    }
    
    XCTAssertEqual(keys.count, count)
}

class MapTests: XCTestCase {
    func testLiteralConversion() {
        let implicitValue: MessagePackValue = ["c": "cookie"]
        XCTAssertEqual(implicitValue, MessagePackValue.Map([.String("c"): .String("cookie")]))
    }

    func testPackFixmap() {
        let packed: Data = [0x81, 0xa1, 0x63, 0xa6, 0x63, 0x6f, 0x6f, 0x6b, 0x69, 0x65]
        XCTAssertEqual(pack(.Map([.String("c"): .String("cookie")])), packed)
    }

    func testUnpackFixmap() {
        let packed: Data = [0x81, 0xa1, 0x63, 0xa6, 0x63, 0x6f, 0x6f, 0x6b, 0x69, 0x65]

        do {
            let unpacked = try unpack(packed)
            XCTAssertEqual(unpacked, MessagePackValue.Map([.String("c"): .String("cookie")]))
        } catch {
            XCTFail("Caught error: \(error)")
        }
    }

    func testPackMap16() {
        testPackMap(16, prefix: [0xde, 0x00, 0x10])
    }

    func testUnpackMap16() {
        do {
            let unpacked = try unpack([0xde, 0x00, 0x10] + payload(16))
            XCTAssertEqual(unpacked, MessagePackValue.Map(map(16)))
        } catch {
            XCTFail("Caught error: \(error)")
        }
    }

    func testPackMap32() {
        testPackMap(0x1_0000, prefix: [0xdf, 0x00, 0x01, 0x00, 0x00])
    }

    func testUnpackMap32() {
        do {
            let unpacked = try unpack([0xdf, 0x00, 0x01, 0x00, 0x00] + payload(0x1_0000))
            XCTAssertEqual(unpacked, MessagePackValue.Map(map(0x1_0000)))
        } catch {
            XCTFail("Caught error: \(error)")
        }
    }
}
