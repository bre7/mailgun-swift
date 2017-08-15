Unofficial Swift library to interface with Mailgun's API.


This is just a quick Swift version of their SDK. The API is pretty much the same for now (great & simple example to use a DSL-styled API).

```swift
let someImage = UIImage(named: "randomName")!

let message = MailgunMessage(from:"Excited User <someone@sample.org>",
                             to:"Jay Baird <jay.baird@rackspace.com>",
                             message:"Mailgun is awesome!",
                             body:"Mailgun is great, here is a picture of a cat.")
message.add(image: someImage, named: "image01", type: .jpeg)

let mailgun = Mailgun(apiKey: "key-1111111111111", domain: "samples.mailgun.org")
mailgun.send(message: message) { result in
    switch result {
    case .success(let messageId):
        print(messageId)
    case .failure(let error):
        print(error)
    }
}
```

**Why?** Mailgun's objc SDK hasn't been updated in quite some time and lacks improvements when using Swift (or *modern objc*) like nullability annotations, etc.


PRs/issues are welcome 😁

---

TODO:
===

- [ ] Improved error handling (remove !s)
- [ ] DSL-style API
- [ ] Mailing list APIs (add, remove, check) 
- [ ] Linux support
- [ ] Queue operations (work offline)
