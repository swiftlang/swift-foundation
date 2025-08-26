//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Swift port of [Native-JSON Benchmark](https://github.com/miloyip/nativejson-benchmark)
/*
The MIT License (MIT)

Copyright (c) 2014 Milo Yip

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

struct TwitterArchive : Codable, Equatable {
    let statuses : [Status]

    struct Status : Codable, Equatable {
        let id : UInt64
        let lang : String
        let text : String
        let source : String
        let metadata : [String:String]
        let user : User
        let place : String?
    }

    struct StatusEntities : Codable, Equatable {
        let hashtags : [Hashtag]
        let media : [MediaItem]
    }

    struct Hashtag : Codable, Equatable {
        let indices : [UInt64]
        let text : String
    }

    struct MediaItem : Codable, Equatable {
        let display_url : String
        let expanded_url : String
        let id : UInt64
        let indices : [UInt64]
        let media_url : String
        let source_status_id : UInt64
        let type : String
        let url : String

        struct Size : Codable, Equatable {
            let h : UInt64
            let w : UInt64
            let resize : String
        }
        let sizes : [String:Size]
    }

    struct User : Codable, Equatable {
        let created_at : String
        let default_profile : Bool
        let description : String
        let favourites_count : UInt64
        let followers_count : UInt64
        let friends_count : UInt64
        let id : UInt64
        let lang : String
        let name : String
        let profile_background_color : String
        let profile_background_image_url : String
        let profile_banner_url : String?
        let profile_image_url : String?
        let profile_use_background_image : Bool
        let screen_name : String
        let statuses_count : UInt64
        let url : String?
        let verified: Bool
    }
}
