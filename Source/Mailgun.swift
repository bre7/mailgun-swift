// Mailgun.swift
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

import Alamofire

private func TODO() {
    fatalError("Not yet implemented")
}

/**
 The SDK allows your macOS, iOS or Linux swift application to connect with the [Mailgun](http://www.mailgun.com) programmable email platform. Send and manage mailing list subscriptions from your desktop or mobile applications and connect with your users directly in your application.

 *Requirements* The Alamofire library is required for the `Mailgun` client library.

 ## Easy Image Attaching

 Using MailgunMessage will allow you to attach `UIImage` or `NSImage` instances to a message. It will handle converting the image for you and attaching it either inline or to the message header.

 ## This SDK is not 1:1 to the REST API

 At this time the full Mailgun REST API is not supported. Currently support is only provided to send messages, subscribe/unsubscribe from mailing lists and to check mailing lists subscriptions.

 *Note* These features may be implemented at a later date.

 ## Sending Example

 let mailgun = Mailgun(apiKey: "key-3ax6xnjp29jd6fds4gc373sgvjxteol0", domain: "samples.mailgun.org")
 mailgun.sendMessage(to: "Jay Baird <jay.baird@rackspace.com>",
                     from:"Excited User <someone@sample.org>",
                     subject:"Mailgun is awesome!",
                     body:"A unicode snowman for you! ☃")

 ## Installing

 1. Install via Cocoapods

 pod 'MailgunSwift', :git => 'https://github.com/bre7/mailgun-swift.git', :branch => 'master'

 2. Install via Source

 1. Clone the repository.
 2. Copy all the Swift files inside the **Source** folder to your project.
 3. There's no step three!

 */
public struct Mailgun {
    private let apiUrl = "https://api.mailgun.net/v2"

    private let configuration  = URLSessionConfiguration.default
    private let sessionManager: Alamofire.SessionManager

    /// Callback used after a message is sent. Will return Error or the message's `messageId`
    public typealias SendMessageCallback = (Result<String>) -> Void
    public typealias MailingListQueryCallback = (Result<NSDictionary>) -> Void
    public typealias MailingListAddRemoveCallback = (Result<Void>) -> Void

    public enum APIError: Error {
        case invalidJSON
        case invalidResponse
    }

    // MARK: - Mailgun Client Setup

    private let apiKey: String
    private let domain: String
    private let authHeaders: HTTPHeaders

    public init(apiKey: String, domain: String) {
        self.apiKey = apiKey
        self.domain = domain

        self.configuration.httpAdditionalHeaders = ["Accept" : "application/json"]
        self.sessionManager = Alamofire.SessionManager(configuration: configuration)

        let authorizationHeader = Request.authorizationHeader(user: "api", password: apiKey)!
        self.authHeaders = [authorizationHeader.key : authorizationHeader.value]
    }

    // MARK: - Sending an Ad-Hoc Mailgun Message

    /// Sends a previously constructed `MailgunMessage` with the provided callback.
    ///
    /// - Parameters:
    ///   - message: Message to be sent
    ///   - completion: Completion block (success/failure)
    public func send(message: MailgunMessage, completion: SendMessageCallback? = nil) {
        let messagePath = "/\(domain)/messages"

        Alamofire.upload(
            multipartFormData: { multipartFormData in
                self.addFormData(to: multipartFormData, from: message)
            },
            to: apiUrl + messagePath,
            method: .post,
            headers: authHeaders,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON { response in

                        if let json = response.result.value as? [String:AnyObject] {
                            debugPrint(json)
                            if let messageId = json["id"] as? String {
                                completion?(.success(messageId))
                            } else {
                                completion?(.failure(APIError.invalidJSON))
                            }
                        } else {
                            debugPrint("Request: \(response.request!)")
                            debugPrint("Response: \(response.response!)")
                            debugPrint("Result: \(response.result)")
                            let error = response.result.error ?? APIError.invalidResponse
                            completion?(.failure(error))
                        }
                    }
                case .failure(let encodingError):
                    debugPrint(encodingError)
                    completion?(.failure(encodingError))
                }
            }
        )

    }


    /// Sends a simple message with an optional callback.
    ///
    /// - Parameters:
    ///   - to: The message recipient
    ///   - from: The message sender.
    ///   - subject: The message subject.
    ///   - body: The body of the message.
    public func sendMessage(to: String, from: String, subject: String, body: String, callback: SendMessageCallback? = nil) {
        let message = MailgunMessage(from: from, to: to, message: subject, body: body)
        self.send(message: message, completion: callback)
    }

    /// Add multiparm form data to the corresponding Alamofire class.
    ///
    /// - Parameters:
    ///   - multipartFormData: multipart form data's container
    ///   - message: Messsage being sent
    fileprivate func addFormData(to multipartFormData: MultipartFormData, from message: MailgunMessage) {
        let parameters = message.dictionary()

        // Send parameters before files
        for (key, value) in parameters {
            multipartFormData.append(value.data(using: .utf8)!, withName: key)
        }

        for (index, attachment) in message.attachments.enumerated() {
            let name = "attachment[\(index)]"
            multipartFormData.append(attachment.value.data, withName: name, fileName: attachment.key, mimeType: attachment.value.type)
        }

        for (index, attachment) in message.inlineAttachments.enumerated() {
            let name = "attachment[\(index)]"
            multipartFormData.append(attachment.value.data, withName: name, fileName: attachment.key, mimeType: attachment.value.type)
        }
    }

    // MARK: - Checking Mailing List Subscription


    /// Checks if the given email address is a current subscriber to the specified mailing list.
    ///
    /// - Parameters:
    ///   - list: The mailing list to check for the provided email address.
    ///   - email: Email address to check for list membership.
    ///   - callback: Will return Dictionary with member information or a 404 error if it the user was not found as a subscriber to `list`
    public func checkSubscriptionTo(list: String, email: String, callback: MailingListQueryCallback) {
        TODO()
    }


    /// Unsubscribes the given email address to the specified mailing list.
    ///
    /// - Parameters:
    ///   - list: The mailing list to unsubscribe the given email address from.
    ///   - email: Email address to check for list membership.
    ///   - callback: Error if the user was not found as a subscriber to `list`
    public func unsubscribeTo(list: String, email: String, callback: MailingListAddRemoveCallback) {
        TODO()
    }

    /// Subscribes the given email address to the specified mailing list.
    ///
    /// - Parameters:
    ///   - list: The mailing list to subscribe the given email address to.
    ///   - email: Email address to subscribe.
    ///   - callback: Error if there's an error subscribing the user to the given mailing list.
    public func subscribeTo(list: String, email: String, callback: MailingListAddRemoveCallback) {
        TODO()
    }
}
