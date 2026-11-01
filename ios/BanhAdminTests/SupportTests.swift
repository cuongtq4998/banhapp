import BanhCore
import Foundation
import Testing
import UIKit
@testable import BanhAdmin

struct FieldRulesTests {
    @Test func numbersAreGroupedWithDotsAndParsedFromDigitsOnly() {
        #expect(FieldRules.grouped("1500000") == "1.500.000")
        #expect(FieldRules.number("1.500.000 đ") == 1_500_000)
        #expect(FieldRules.integer("0", AStrings.fFee, range: 1...10) != nil)
        #expect(FieldRules.integer("5", AStrings.fFee, range: 1...10) == nil)
        #expect(FieldRules.integer("", AStrings.fFee, range: 1...10) == AStrings.errRequired(AStrings.fFee))
    }

    @Test func vietnamesePhonesBecomeE164() {
        #expect(FieldRules.e164("0900 000 000") == "+84900000000")
        #expect(FieldRules.e164("+84900000000") == "+84900000000")
        #expect(FieldRules.e164("84900000000") == "+84900000000")
        #expect(FieldRules.e164("123") == nil)
        #expect(FieldRules.e164("09abc") == nil)
    }

    @Test func textLimitsCountCharactersAfterTrimming() {
        #expect(FieldRules.text("  ", AStrings.fShopName, max: 5) == AStrings.errRequired(AStrings.fShopName))
        #expect(FieldRules.text("abcdef", AStrings.fShopName, max: 5) == AStrings.errTooLong(AStrings.fShopName, max: 5))
        #expect(FieldRules.text("abc", AStrings.fZalo, max: 5, min: 3) == nil)
        #expect(FieldRules.text("ab", AStrings.fZalo, max: 5, min: 3) != nil)
    }
}

struct CakeImageTests {
    private func png(_ width: Int, _ height: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func size(_ data: Data) -> CGSize? {
        UIImage(data: data).map { CGSize(width: $0.size.width * $0.scale, height: $0.size.height * $0.scale) }
    }

    @Test func largePhotoIsScaledToTheTargetAndEncodedAsJpeg() throws {
        let jpeg = try CakeImage.prepare(png(4000, 3000)).get()
        #expect(jpeg.starts(with: [0xFF, 0xD8, 0xFF]))
        let side = try #require(size(jpeg))
        #expect(max(side.width, side.height) == 1600 && min(side.width, side.height) >= 200)
        #expect(jpeg.count <= CakeImage.maxBytes)
    }

    @Test func smallPhotoKeepsItsSizeWithinTheServerRange() throws {
        let side = try #require(size(try CakeImage.prepare(png(600, 400)).get()))
        #expect(side == CGSize(width: 600, height: 400))
    }

    @Test func tooSmallOrBrokenPicturesFail() {
        #expect(CakeImage.prepare(png(150, 150)) == .failure(.tooSmall))
        #expect(CakeImage.prepare(png(4100, 300)) == .failure(.tooLarge))
        #expect(CakeImage.prepare(Data("nope".utf8)) == .failure(.unreadable))
    }

    @Test func qualityAndSizeShrinkUntilTheByteLimitIsMet() throws {
        let noisy = png(1200, 800)
        let jpeg = try CakeImage.prepare(noisy, maxBytes: 20_000).get()
        #expect(jpeg.count <= 20_000)
        #expect(CakeImage.prepare(noisy, maxBytes: 10) == .failure(.tooManyBytes))
    }
}

struct MultipartAndFormattingTests {
    @Test func multipartHasFieldsFileAndClosingBoundary() {
        var form = MultipartBody(boundary: "B")
        form.addField("name", "Banh")
        form.addFile("image", filename: "cake.jpg", mimeType: "image/jpeg", bytes: Data([1, 2, 3]))
        let text = String(decoding: form.finished, as: UTF8.self)
        #expect(form.contentType == "multipart/form-data; boundary=B")
        #expect(text.contains("name=\"name\"\r\n\r\nBanh\r\n"))
        #expect(text.contains("name=\"image\"; filename=\"cake.jpg\"\r\nContent-Type: image/jpeg"))
        #expect(text.hasSuffix("--B--\r\n"))
    }

    /// Fix (a) of part 1: the picked day is the shop day, whatever zone the phone is in.
    @Test func pickedDateUsesTheShopZoneNotTheDeviceZone() throws {
        defer { setenv("TZ", "UTC", 1); tzset(); NSTimeZone.resetSystemTimeZone() }
        // 2026-11-03 01:00 UTC is 08:00 on 3 Nov in Vietnam but 18:00 on 2 Nov in Los Angeles.
        let instant = Date(timeIntervalSince1970: 1_793_667_600)
        for zone in ["America/Los_Angeles", "Pacific/Kiritimati", "UTC"] {
            setenv("TZ", zone, 1)
            tzset()
            NSTimeZone.resetSystemTimeZone()
            #expect(AdminFormatting.wire(of: instant) == "2026-11-03", "device zone \(zone)")
        }
        setenv("TZ", "America/Los_Angeles", 1)
        tzset()
        NSTimeZone.resetSystemTimeZone()
        var device = Calendar(identifier: .gregorian)
        device.timeZone = TimeZone.current
        #expect(device.component(.day, from: instant) == 2, "the device zone would have given the 2nd")
    }

    @Test func pickerOpensOnTheServerDay() {
        #expect(AdminFormatting.wire(of: AdminFormatting.pickerDate("2026-11-02")) == "2026-11-02")
        #expect(AdminFormatting.shopTimeZone.identifier == "Asia/Ho_Chi_Minh")
    }
}
