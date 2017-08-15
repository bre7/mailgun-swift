// MailgunMessage.swift
//
// Copyright (c) 2013 Rackspace Hosting (http://rackspace.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import Cocoa
#endif

#if os(iOS)
    public enum ImageFormat: String {
        case png
        case jpeg

        var mimeType: String {
            switch self {
            case .jpeg:
                return "image/jpg"
            case .png:
                return "image/png"
            }
        }

        var fileExtension: String {
            return rawValue
        }
    }
#elseif os(macOS)
    public enum ImageFormat: String {
        case bmp
        case gif
        case jpeg
        case jpeg2000
        case png
        case tiff

        var mimeType: String {
            switch self {
            case .tiff:
                return "image/tiff"
            case .png:
                return "image/png"
            case .gif:
                return "image/gif"
            case .jpeg:
                return "image/jpg"
            case .jpeg2000:
                return "image/jp2"
            case .bmp:
                return "image/bmp"
            }
        }

        var fileExtension: String {
            switch self {
            case .jpeg2000:
                return ImageFormat.jpeg.rawValue
            default:
                return rawValue
            }
        }
    }
#endif

public enum ClickTrackingMode: MailgunConvertible {
    case htmlClicks
    case allClicks

    func toMg() -> String {
        return self == .htmlClicks ? "htmlonly" : "yes"
    }
}

public class MailgunMessage {

    static var rfc2822Formatter: DateFormatter = {
        $0.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return $0
    }(DateFormatter())


    // MARK: - Managing Message Setup

    /// Email address for From header
    public let from: String

    /// Email address of the recipient(s). Example: "Bob <bob@host.com>".
    public var to: [String]

    /// Email address of the CC recipient(s). Example: "Bob <bob@host.com>".
    public var cc = [String]()

    /// Email address of the BCC recipient(s). Example: "Bob <bob@host.com>".
    public var bcc = [String]()

    /// Message subject
    public let subject: String

     /// Body of the message, text version
    public var text: String

    /// Body of the message. HTML version
    public var html: String? = nil

    // MARK: - Mailgun Message Configuration

    /// ID of the campaign the message belongs to. See [Campaign Analytics](http://documentation.mailgun.net/user_manual.html#um-campaign-analytics) for details.
    public var campaign: String? = nil

    /// An array of tag strings. See [Tagging](http://documentation.mailgun.net/user_manual.html#tagging) for more information.
    public var tags = [String]()

    /// `NSMutableDictionary` of custom MIME headers to the message. For example, `Reply-To` to specify a Reply-To address.
    public var headers = [String:String]()

    /// `NSMutableDictionary` for attaching custom JSON data to the message. See [Attaching Data to Messages](http://documentation.mailgun.net/user_manual.html#manual-customdata) for more information.
    public var variables = [String:String]()

    /// `Dictionary` of attachments to the message. Type is: [attachment-name : (attachment-mime-type,attachment-data)]
    public private(set) var attachments = [String : (type: String, data: Data)]()

    /// `Dictionary` of inline message attachments. Type is: [attachment-name : (attachment-mime-type,attachment-data)]
    public private(set) var inlineAttachments = [String : (type: String, data: Data)]()

    /// Enables/disables DKIM signatures on per-message basis.
    public var dkim: Bool = false

    /// Enables sending in test mode. See [Sending in Test Mode](http://documentation.mailgun.net/user_manual.html#manual-testmode)
    public var testing: Bool = false

    /// Toggles tracking on a per-message basis, see [Tracking Messages](http://documentation.mailgun.net/user_manual.html#tracking-messages) for details.
    public var tracking: Bool = false

    /// Toggles opens tracking on a per-message basis. Has higher priority than domain-level setting.
    public var trackOpens: Bool = false

    /// An `Date` representing the desired time of delivery.
    public var deliverAt: Date? = nil

    /// Toggles clicks tracking on a per-message basis. Has higher priority than domain-level setting.
    public let trackClicks: ClickTrackingMode? = nil

    // MARK: - Creating and Initializing a Mailgun Message

    public init(from: String, to: String, message: String, body: String) {
        self.from = from
        self.to = to.split(separator: ",").map { String($0) }
        self.subject = message
        self.text = body
    }

    /// ToDo: Use Codable
    func dictionary() -> [String : String] {
        var params: [String:String] = [
            "to": self.to.joined(separator: ","),
            "from": self.from,
            "subject": self.subject,
            "text": self.text
        ]

        if !self.cc.isEmpty {
            params["cc"] = self.cc.joined(separator: ",")
        }
        if !self.bcc.isEmpty {
            params["bcc"] = self.bcc.joined(separator: ",")
        }
        if let html = self.html {
            params["html"] = html
        }
        if let campaign = self.campaign {
            params["o:campaign"] = campaign
        }
        if let deliverAt = self.deliverAt {
            params["o:deliverytime"] = MailgunMessage.rfc2822Formatter.string(from: deliverAt)
        }

        let otherParams: [String:String] = [
            "o:dkim": self.dkim.toMg(),
            "o:testmode": self.testing.toMg(),
            "o:tracking": self.tracking.toMg(),
            "o:tracking-clicks": self.trackClicks?.toMg() ?? "no",
            "o:tracking-opens": self.trackOpens.toMg()
        ]
        params.merge(otherParams, uniquingKeysWith: { (_, new) in new })

        headers.forEach { header in
            let key = String(format: "h:X-%@", header.key)
            params[key] = header.value
        }

        variables.forEach { variable in
            let key = String(format: "v:%@", variable.key)
            params[key] = variable.value
        }

        return params
    }

    // MARK: - Adding Attachments

    /// Adds an attachment to the receiver.
    ///
    /// - Parameters:
    ///   - attachment: The `Data` to be attached to the message.
    ///   - named: The name used to identify this attachment in the message.
    ///   - type: The MIME type used to describe the contents of `data`.
    public func add(attachment data: Data, named name: String, type mimeType: String) {
        self.attachments[name] = (mimeType, data)
    }

    #if os(iOS)

    /// Adds an `UIImage` as an attachment to the receiver.
    ///
    /// - Parameters:
    ///   - image: The `UIImage` to be attached to the message.
    ///   - named: The name used to identify this attachment in the message.
    ///   - type: The `ImageFormat` to identify this image as a JPEG or a PNG.
    ///   - inline: Indicates whether the image should be inlined or not (false by default)
    public func add(image: UIImage, named name: String, type: ImageFormat, inline: Bool = false) {
        let mimeType = type.mimeType
        let data: Data!

        switch type {
        case .jpeg:
            data = UIImageJPEGRepresentation(image, 0.9)!
        case .png:
            data = UIImagePNGRepresentation(image)!
        }

        // Append extension if needed
        let filename = name.hasSuffix(".\(type.fileExtension)") ? name : name + ".\(type.fileExtension)"
        if inline {
            self.inlineAttachments[filename] = (mimeType, data)
        } else {
            self.add(attachment: data, named: filename, type: mimeType)
        }
    }

    #elseif os(macOS)

    /// Adds a `NSImage` as an attachment to the receiver.
    ///
    /// - Parameters:
    ///   - image: The `NSImage` to be attached to the message.
    ///   - named: The name used to identify this attachment in the message.
    ///   - type: The `NSBitmapImageFileType` identifying the type of image as JPEG or a PNG.
    ///   - inline: Indicates whether the image should be inlined or not (false by default)
    public func add(image: NSImage, named name: String, type: ImageFormat, inline: Bool = false) {
        let mimeType = type.mimeType
        let imgRep = image.representations.first!
        let data = imgRep.representation(using:type, properties:[:])!

        // Append extension if needed
        let filename = name.hasSuffix(".\(type.fileExtension)") ? name : name + ".\(type.fileExtension)"
        if inline {
            self.inlineAttachments[filename] = (mimeType, data)
        } else {
            self.add(attachment: data, named: filename, type: mimeType)
        }
    }

    #endif

}
