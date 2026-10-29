import XCTest
@testable import App

final class PhoneAndTextTests: XCTestCase {
    func testCommonWritingsOfOneNumberNormaliseAlike() {
        for writing in ["0912345678", "091 234 5678", "091.234.5678", "091-234-5678", "(091) 234 5678",
                        "+84912345678", "+84 912 345 678", "84912345678", "+84(0)912345678".replacingOccurrences(of: "(0)", with: "")] {
            XCTAssertEqual(PhoneNumber.normalise(writing), "+84912345678", writing)
        }
    }

    func testOnlyMobileNumbersPass() {
        for second in ["3", "5", "7", "8", "9"] { XCTAssertNotNil(PhoneNumber.normalise("0\(second)12345678"), second) }
        for bad in ["", "0212345678", "0112345678", "0412345678", "0612345678", "091234567", "09123456789", "+8412345678",
                    "8412345678", "+85912345678", "abc", "0912 345 67a", "٠٩١٢٣٤٥٦٧٨", "0084912345678"] {
            XCTAssertNil(PhoneNumber.normalise(bad), bad)
        }
    }

    func testTextIsNFCTrimmedAndCountedInCodePoints() {
        let decomposed = "Nguye\u{0302}\u{0303}n"
        XCTAssertEqual(try OrderText.normalise(" \(decomposed) ", minLength: 1, maxLength: 6, allowsNewline: false).get(), "Nguyễn")
        XCTAssertEqual(OrderText.normalise("abcdefg", minLength: 1, maxLength: 6, allowsNewline: false), .failure(.tooLong))
        XCTAssertEqual(OrderText.normalise("  ", minLength: 1, maxLength: 6, allowsNewline: false), .failure(.empty))
        XCTAssertEqual(OrderText.normalise("  ", minLength: 0, maxLength: 6, allowsNewline: true), .success(""))
        XCTAssertEqual(OrderText.normalise("a\u{0}b", minLength: 1, maxLength: 6, allowsNewline: true), .failure(.controlCharacter))
    }

    func testRequestHashIgnoresLineOrderAndWriting() {
        let second = UUID(uuidString: "0b8f1f0e-1111-4a00-8000-000000000009")!
        let a = OrderTestData.request.replacing(items: [.init(productID: OrderTestData.productID, quantity: 1), .init(productID: second, quantity: 1)])
        let b = OrderTestData.request.replacing(items: [.init(productID: second, quantity: 1), .init(productID: OrderTestData.productID, quantity: 1)])
        XCTAssertEqual(OrderRequestHash.make(a), OrderRequestHash.make(b))
        XCTAssertEqual(OrderRequestHash.make(a).count, 64)
        XCTAssertNotEqual(OrderRequestHash.make(a), OrderRequestHash.make(a.replacing(expected: 1)))
        XCTAssertNotEqual(OrderRequestHash.make(a), OrderRequestHash.make(a.replacing(date: AvailabilityTestData.date("2026-11-06"))))
    }
}
