# Early Data Support in URLSession

* Proposal: [SF-NNNN](NNNN-urlsession-early-data.md)
* Authors: [Guoye Zhang](https://github.com/guoye-zhang)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: [swiftlang/swift-corelibs-foundation#5216](https://github.com/swiftlang/swift-corelibs-foundation/pull/5216)
* Review: ([pitch](https://forums.swift.org/t/pitch-early-data-support-in-urlsession-on-darwin/80071))

## Introduction

HTTP/3 early data enables request transmission on a new connection with no round trip delays (0-RTT), improving the startup time of apps. We are introducing a new flag `enablesEarlyData` on URLSessionConfiguration to allow developers to opt in to the feature.

The flag is not available on non-Darwin platforms at this moment.

## Example usage

Adopting HTTP early data and loading a URL.

```swift
let configuration = URLSessionConfiguration.default
configuration.usesClassicLoadingMode = false
configuration.enablesEarlyData = true

let session = URLSession(configuration: configuration)
let (data, response) = try await session.data(from: url)
```

## Detailed design

By opting in to the flag, URLSession persists HTTP/3 connection state along with QUIC and TLS session state, allowing 0-RTT transmission of safe requests (GET or HEAD requests) when establishing a new connection to the same host.

```swift
open class URLSessionConfiguration {

    /* Enables HTTP/3 0-RTT early data transmission of safe requests (GET or HEAD
     requests).

     WARNING: Inclusion in TLS early data changes the security guarantees offered
     by TLS.

     Requests sent in early data are not covered by anti-replay security
     protections. Early data must be idempotent and the impact of adversarial
     replays must be carefully evaluated, as the data may be replayed. Early data
     also does not provide full forward secrecy; data transmitted is more
     susceptible to data breach and security compromise of the server, even if
     the breach happens after the data was transmitted.

     See Section 8 of RFC8446 for more details.

     https://datatracker.ietf.org/doc/html/rfc8446#section-8

     See RFC8470 for additional discussion and security considerations.

     https://datatracker.ietf.org/doc/html/rfc8470

     If these risks are acceptable for your use case, set this property to true.
     If unsure, false is the safest option.

     NOTE: Not supported in the classic loading mode.

     Defaults to false.
     */
    @available(*, unavailable, message: "Not available on non-Darwin platforms")
    open var enablesEarlyData: Bool
}
```

## Source compatibility

No impact.

## Implications on adoption

This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Future directions

Some apps use unsafe method such as POSTs to transfer idempotent data, and they might want to send those requests in the early data. This can be supported in the form of a flag `URLRequest.unsafeAllowsInEarlyData` on a per-request basis. However, it is not needed for the majority of the use cases.

## Alternatives considered

### Enabling early data by default

0-RTT early data can be replayed by an attacker, and we do not know if the server has sufficient mitigations of such an attack. Therefore we ask developers to enable this flag at their own risk.
