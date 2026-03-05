//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//


import NewCodable
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif FOUNDATION_FRAMEWORK
import Foundation
#endif

enum JSONPass { }

extension JSONPass {
    struct Test1: Codable, JSONCodable, Equatable {
        let glossary: Glossary

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var glossary: Glossary?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "glossary":
                        glossary = try valueDecoder.decode(Glossary.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let glossary = glossary else {
                    throw CodingError.keyNotFound("glossary")
                }

                return Test1(glossary: glossary)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: "glossary", value: glossary)
            }
        }

        struct Glossary: Codable, JSONCodable, Equatable {
            let title: String
            let glossDiv: GlossDiv

            enum CodingKeys: String, CodingKey {
                case title
                case glossDiv = "GlossDiv"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var title: String?
                    var glossDiv: GlossDiv?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "title":
                            title = try valueDecoder.decode(String.self)
                        case "GlossDiv":
                            glossDiv = try valueDecoder.decode(GlossDiv.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let title = title else {
                        throw CodingError.keyNotFound("title")
                    }
                    guard let glossDiv = glossDiv else {
                        throw CodingError.keyNotFound("glossDiv")
                    }

                    return Glossary(title: title, glossDiv: glossDiv)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.title.stringValue, value: title)
                    try objectEncoder.encode(key: CodingKeys.glossDiv.stringValue, value: glossDiv)
                }
            }
        }

        struct GlossDiv: Codable, JSONCodable, Equatable {
            let title: String
            let glossList: GlossList

            enum CodingKeys: String, CodingKey {
                case title
                case glossList = "GlossList"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var title: String?
                    var glossList: GlossList?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "title":
                            title = try valueDecoder.decode(String.self)
                        case "GlossList":
                            glossList = try valueDecoder.decode(GlossList.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let title = title else {
                        throw CodingError.keyNotFound("title")
                    }
                    guard let glossList = glossList else {
                        throw CodingError.keyNotFound("glossList")
                    }

                    return GlossDiv(title: title, glossList: glossList)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.title.stringValue, value: title)
                    try objectEncoder.encode(key: CodingKeys.glossList.stringValue, value: glossList)
                }
            }
        }

        struct GlossList: Codable, JSONCodable, Equatable {
            let glossEntry: GlossEntry

            enum CodingKeys: String, CodingKey {
                case glossEntry = "GlossEntry"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var glossEntry: GlossEntry?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "GlossEntry":
                            glossEntry = try valueDecoder.decode(GlossEntry.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let glossEntry = glossEntry else {
                        throw CodingError.keyNotFound("glossEntry")
                    }

                    return GlossList(glossEntry: glossEntry)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.glossEntry.stringValue, value: glossEntry)
                }
            }
        }

        struct GlossEntry: Codable, JSONCodable, Equatable {
            let id, sortAs, glossTerm, acronym: String
            let abbrev: String
            let glossDef: GlossDef
            let glossSee: String

            enum CodingKeys: String, CodingKey {
                case id = "ID"
                case sortAs = "SortAs"
                case glossTerm = "GlossTerm"
                case acronym = "Acronym"
                case abbrev = "Abbrev"
                case glossDef = "GlossDef"
                case glossSee = "GlossSee"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var id: String?
                    var sortAs: String?
                    var glossTerm: String?
                    var acronym: String?
                    var abbrev: String?
                    var glossDef: GlossDef?
                    var glossSee: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "ID":
                            id = try valueDecoder.decode(String.self)
                        case "SortAs":
                            sortAs = try valueDecoder.decode(String.self)
                        case "GlossTerm":
                            glossTerm = try valueDecoder.decode(String.self)
                        case "Acronym":
                            acronym = try valueDecoder.decode(String.self)
                        case "Abbrev":
                            abbrev = try valueDecoder.decode(String.self)
                        case "GlossDef":
                            glossDef = try valueDecoder.decode(GlossDef.self)
                        case "GlossSee":
                            glossSee = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let id = id else { throw CodingError.keyNotFound("id") }
                    guard let sortAs = sortAs else { throw CodingError.keyNotFound("sortAs") }
                    guard let glossTerm = glossTerm else { throw CodingError.keyNotFound("glossTerm") }
                    guard let acronym = acronym else { throw CodingError.keyNotFound("acronym") }
                    guard let abbrev = abbrev else { throw CodingError.keyNotFound("abbrev") }
                    guard let glossDef = glossDef else { throw CodingError.keyNotFound("glossDef") }
                    guard let glossSee = glossSee else { throw CodingError.keyNotFound("glossSee") }

                    return GlossEntry(id: id, sortAs: sortAs, glossTerm: glossTerm, acronym: acronym, abbrev: abbrev, glossDef: glossDef, glossSee: glossSee)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.id.stringValue, value: id)
                    try objectEncoder.encode(key: CodingKeys.sortAs.stringValue, value: sortAs)
                    try objectEncoder.encode(key: CodingKeys.glossTerm.stringValue, value: glossTerm)
                    try objectEncoder.encode(key: CodingKeys.acronym.stringValue, value: acronym)
                    try objectEncoder.encode(key: CodingKeys.abbrev.stringValue, value: abbrev)
                    try objectEncoder.encode(key: CodingKeys.glossDef.stringValue, value: glossDef)
                    try objectEncoder.encode(key: CodingKeys.glossSee.stringValue, value: glossSee)
                }
            }
        }

        struct GlossDef: Codable, JSONCodable, Equatable {
            let para: String
            let glossSeeAlso: [String]

            enum CodingKeys: String, CodingKey {
                case para
                case glossSeeAlso = "GlossSeeAlso"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var para: String?
                    var glossSeeAlso: [String]?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "para":
                            para = try valueDecoder.decode(String.self)
                        case "GlossSeeAlso":
                            glossSeeAlso = try valueDecoder.decode([String].self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let para = para else {
                        throw CodingError.keyNotFound("para")
                    }
                    guard let glossSeeAlso = glossSeeAlso else {
                        throw CodingError.keyNotFound("glossSeeAlso")
                    }

                    return GlossDef(para: para, glossSeeAlso: glossSeeAlso)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.para.stringValue, value: para)
                    try objectEncoder.encode(key: CodingKeys.glossSeeAlso.stringValue, value: glossSeeAlso)
                }
            }
        }
    }
}

extension JSONPass {
    struct Test2: Codable, JSONCodable, Equatable {
        let menu: Menu

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var menu: Menu?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "menu":
                        menu = try valueDecoder.decode(Menu.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let menu = menu else {
                    throw CodingError.keyNotFound("menu")
                }

                return Test2(menu: menu)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: "menu", value: menu)
            }
        }

        struct Menu: Codable, JSONCodable, Equatable {
            let id, value: String
            let popup: Popup

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var id: String?
                    var value: String?
                    var popup: Popup?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "id":
                            id = try valueDecoder.decode(String.self)
                        case "value":
                            value = try valueDecoder.decode(String.self)
                        case "popup":
                            popup = try valueDecoder.decode(Popup.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let id = id else {
                        throw CodingError.keyNotFound("id")
                    }
                    guard let value = value else {
                        throw CodingError.keyNotFound("value")
                    }
                    guard let popup = popup else {
                        throw CodingError.keyNotFound("popup")
                    }

                    return Menu(id: id, value: value, popup: popup)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "id", value: id)
                    try objectEncoder.encode(key: "value", value: value)
                    try objectEncoder.encode(key: "popup", value: popup)
                }
            }
        }

        struct Popup: Codable, JSONCodable, Equatable {
            let menuitem: [Menuitem]

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var menuitem: [Menuitem]?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "menuitem":
                            menuitem = try valueDecoder.decode([Menuitem].self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let menuitem = menuitem else {
                        throw CodingError.keyNotFound("menuitem")
                    }

                    return Popup(menuitem: menuitem)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "menuitem", value: menuitem)
                }
            }
        }

        struct Menuitem: Codable, JSONCodable, Equatable {
            let value, onclick: String

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var value: String?
                    var onclick: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "value":
                            value = try valueDecoder.decode(String.self)
                        case "onclick":
                            onclick = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let value = value else {
                        throw CodingError.keyNotFound("value")
                    }
                    guard let onclick = onclick else {
                        throw CodingError.keyNotFound("onclick")
                    }

                    return Menuitem(value: value, onclick: onclick)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "value", value: value)
                    try objectEncoder.encode(key: "onclick", value: onclick)
                }
            }
        }
    }
}

extension JSONPass {
    struct Test3: Codable, JSONCodable, Equatable {
        let widget: Widget

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var widget: Widget?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "widget":
                        widget = try valueDecoder.decode(Widget.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let widget = widget else {
                    throw CodingError.keyNotFound("widget")
                }

                return Test3(widget: widget)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: "widget", value: widget)
            }
        }

        struct Widget: Codable, JSONCodable, Equatable {
            let debug: String
            let window: Window
            let image: Image
            let text: Text

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var debug: String?
                    var window: Window?
                    var image: Image?
                    var text: Text?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "debug":
                            debug = try valueDecoder.decode(String.self)
                        case "window":
                            window = try valueDecoder.decode(Window.self)
                        case "image":
                            image = try valueDecoder.decode(Image.self)
                        case "text":
                            text = try valueDecoder.decode(Text.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let debug = debug else { throw CodingError.keyNotFound("debug") }
                    guard let window = window else { throw CodingError.keyNotFound("window") }
                    guard let image = image else { throw CodingError.keyNotFound("image") }
                    guard let text = text else { throw CodingError.keyNotFound("text") }

                    return Widget(debug: debug, window: window, image: image, text: text)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "debug", value: debug)
                    try objectEncoder.encode(key: "window", value: window)
                    try objectEncoder.encode(key: "image", value: image)
                    try objectEncoder.encode(key: "text", value: text)
                }
            }
        }

        struct Image: Codable, JSONCodable, Equatable {
            let src, name: String
            let hOffset, vOffset: Int
            let alignment: String

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var src: String?
                    var name: String?
                    var hOffset: Int?
                    var vOffset: Int?
                    var alignment: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "src":
                            src = try valueDecoder.decode(String.self)
                        case "name":
                            name = try valueDecoder.decode(String.self)
                        case "hOffset":
                            hOffset = try valueDecoder.decode(Int.self)
                        case "vOffset":
                            vOffset = try valueDecoder.decode(Int.self)
                        case "alignment":
                            alignment = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let src = src else { throw CodingError.keyNotFound("src") }
                    guard let name = name else { throw CodingError.keyNotFound("name") }
                    guard let hOffset = hOffset else { throw CodingError.keyNotFound("hOffset") }
                    guard let vOffset = vOffset else { throw CodingError.keyNotFound("vOffset") }
                    guard let alignment = alignment else { throw CodingError.keyNotFound("alignment") }

                    return Image(src: src, name: name, hOffset: hOffset, vOffset: vOffset, alignment: alignment)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "src", value: src)
                    try objectEncoder.encode(key: "name", value: name)
                    try objectEncoder.encode(key: "hOffset", value: hOffset)
                    try objectEncoder.encode(key: "vOffset", value: vOffset)
                    try objectEncoder.encode(key: "alignment", value: alignment)
                }
            }
        }

        struct Text: Codable, JSONCodable, Equatable {
            let data: String
            let size: Int
            let style, name: String
            let hOffset, vOffset: Int
            let alignment, onMouseUp: String

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var data: String?
                    var size: Int?
                    var style: String?
                    var name: String?
                    var hOffset: Int?
                    var vOffset: Int?
                    var alignment: String?
                    var onMouseUp: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "data":
                            data = try valueDecoder.decode(String.self)
                        case "size":
                            size = try valueDecoder.decode(Int.self)
                        case "style":
                            style = try valueDecoder.decode(String.self)
                        case "name":
                            name = try valueDecoder.decode(String.self)
                        case "hOffset":
                            hOffset = try valueDecoder.decode(Int.self)
                        case "vOffset":
                            vOffset = try valueDecoder.decode(Int.self)
                        case "alignment":
                            alignment = try valueDecoder.decode(String.self)
                        case "onMouseUp":
                            onMouseUp = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let data = data else { throw CodingError.keyNotFound("data") }
                    guard let size = size else { throw CodingError.keyNotFound("size") }
                    guard let style = style else { throw CodingError.keyNotFound("style") }
                    guard let name = name else { throw CodingError.keyNotFound("name") }
                    guard let hOffset = hOffset else { throw CodingError.keyNotFound("hOffset") }
                    guard let vOffset = vOffset else { throw CodingError.keyNotFound("vOffset") }
                    guard let alignment = alignment else { throw CodingError.keyNotFound("alignment") }
                    guard let onMouseUp = onMouseUp else { throw CodingError.keyNotFound("onMouseUp") }

                    return Text(data: data, size: size, style: style, name: name, hOffset: hOffset, vOffset: vOffset, alignment: alignment, onMouseUp: onMouseUp)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "data", value: data)
                    try objectEncoder.encode(key: "size", value: size)
                    try objectEncoder.encode(key: "style", value: style)
                    try objectEncoder.encode(key: "name", value: name)
                    try objectEncoder.encode(key: "hOffset", value: hOffset)
                    try objectEncoder.encode(key: "vOffset", value: vOffset)
                    try objectEncoder.encode(key: "alignment", value: alignment)
                    try objectEncoder.encode(key: "onMouseUp", value: onMouseUp)
                }
            }
        }

        struct Window: Codable, JSONCodable, Equatable {
            let title, name: String
            let width, height: Int

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var title: String?
                    var name: String?
                    var width: Int?
                    var height: Int?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "title":
                            title = try valueDecoder.decode(String.self)
                        case "name":
                            name = try valueDecoder.decode(String.self)
                        case "width":
                            width = try valueDecoder.decode(Int.self)
                        case "height":
                            height = try valueDecoder.decode(Int.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let title = title else { throw CodingError.keyNotFound("title") }
                    guard let name = name else { throw CodingError.keyNotFound("name") }
                    guard let width = width else { throw CodingError.keyNotFound("width") }
                    guard let height = height else { throw CodingError.keyNotFound("height") }

                    return Window(title: title, name: name, width: width, height: height)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "title", value: title)
                    try objectEncoder.encode(key: "name", value: name)
                    try objectEncoder.encode(key: "width", value: width)
                    try objectEncoder.encode(key: "height", value: height)
                }
            }
        }
    }
}

extension JSONPass {
    struct Test4: Codable, JSONCodable, Equatable {
        let webApp: WebApp

        enum CodingKeys: String, CodingKey {
            case webApp = "web-app"
        }

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var webApp: WebApp?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "web-app":
                        webApp = try valueDecoder.decode(WebApp.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let webApp = webApp else {
                    throw CodingError.keyNotFound("webApp")
                }

                return Test4(webApp: webApp)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: CodingKeys.webApp.stringValue, value: webApp)
            }
        }

        struct WebApp: Codable, JSONCodable, Equatable {
            let servlet: [Servlet]
            let servletMapping: ServletMapping
            let taglib: Taglib

            enum CodingKeys: String, CodingKey {
                case servlet
                case servletMapping = "servlet-mapping"
                case taglib
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var servlet: [Servlet]?
                    var servletMapping: ServletMapping?
                    var taglib: Taglib?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "servlet":
                            servlet = try valueDecoder.decode([Servlet].self)
                        case "servlet-mapping":
                            servletMapping = try valueDecoder.decode(ServletMapping.self)
                        case "taglib":
                            taglib = try valueDecoder.decode(Taglib.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let servlet = servlet else { throw CodingError.keyNotFound("servlet") }
                    guard let servletMapping = servletMapping else { throw CodingError.keyNotFound("servletMapping") }
                    guard let taglib = taglib else { throw CodingError.keyNotFound("taglib") }

                    return WebApp(servlet: servlet, servletMapping: servletMapping, taglib: taglib)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.servlet.stringValue, value: servlet)
                    try objectEncoder.encode(key: CodingKeys.servletMapping.stringValue, value: servletMapping)
                    try objectEncoder.encode(key: CodingKeys.taglib.stringValue, value: taglib)
                }
            }
        }

        struct Servlet: Codable, JSONCodable, Equatable {
            let servletName, servletClass: String
            let initParam: InitParam?

            enum CodingKeys: String, CodingKey {
                case servletName = "servlet-name"
                case servletClass = "servlet-class"
                case initParam = "init-param"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var servletName: String?
                    var servletClass: String?
                    var initParam: InitParam?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "servlet-name":
                            servletName = try valueDecoder.decode(String.self)
                        case "servlet-class":
                            servletClass = try valueDecoder.decode(String.self)
                        case "init-param":
                            initParam = try valueDecoder.decode(InitParam.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let servletName = servletName else { throw CodingError.keyNotFound("servletName") }
                    guard let servletClass = servletClass else { throw CodingError.keyNotFound("servletClass") }

                    return Servlet(servletName: servletName, servletClass: servletClass, initParam: initParam)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.servletName.stringValue, value: servletName)
                    try objectEncoder.encode(key: CodingKeys.servletClass.stringValue, value: servletClass)
                    if let initParam = initParam {
                        try objectEncoder.encode(key: CodingKeys.initParam.stringValue, value: initParam)
                    }
                }
            }
        }

        struct InitParam: Codable, JSONCodable, Equatable {
            let configGlossaryInstallationAt, configGlossaryAdminEmail, configGlossaryPoweredBy, configGlossaryPoweredByIcon: String?
            let configGlossaryStaticPath, templateProcessorClass, templateLoaderClass, templatePath: String?
            let templateOverridePath, defaultListTemplate, defaultFileTemplate: String?
            let useJSP: Bool?
            let jspListTemplate, jspFileTemplate: String?
            let cachePackageTagsTrack, cachePackageTagsStore, cachePackageTagsRefresh, cacheTemplatesTrack: Int?
            let cacheTemplatesStore, cacheTemplatesRefresh, cachePagesTrack, cachePagesStore: Int?
            let cachePagesRefresh, cachePagesDirtyRead: Int?
            let searchEngineListTemplate, searchEngineFileTemplate, searchEngineRobotsDB: String?
            let useDataStore: Bool?
            let dataStoreClass, redirectionClass, dataStoreName, dataStoreDriver: String?
            let dataStoreURL, dataStoreUser, dataStorePassword, dataStoreTestQuery: String?
            let dataStoreLogFile: String?
            let dataStoreInitConns, dataStoreMaxConns, dataStoreConnUsageLimit: Int?
            let dataStoreLogLevel: String?
            let maxURLLength: Int?
            let mailHost, mailHostOverride: String?
            let log: Int?
            let logLocation, logMaxSize: String?
            let dataLog: Int?
            let dataLogLocation, dataLogMaxSize, removePageCache, removeTemplateCache: String?
            let fileTransferFolder: String?
            let lookInContext, adminGroupID: Int?
            let betaServer: Bool?

            enum CodingKeys: String, CodingKey {
                case configGlossaryInstallationAt
                case configGlossaryAdminEmail
                case configGlossaryPoweredBy
                case configGlossaryPoweredByIcon
                case configGlossaryStaticPath
                case templateProcessorClass, templateLoaderClass, templatePath, templateOverridePath, defaultListTemplate, defaultFileTemplate, useJSP, jspListTemplate, jspFileTemplate, cachePackageTagsTrack, cachePackageTagsStore, cachePackageTagsRefresh, cacheTemplatesTrack, cacheTemplatesStore, cacheTemplatesRefresh, cachePagesTrack, cachePagesStore, cachePagesRefresh, cachePagesDirtyRead, searchEngineListTemplate, searchEngineFileTemplate
                case searchEngineRobotsDB
                case useDataStore, dataStoreClass, redirectionClass, dataStoreName, dataStoreDriver
                case dataStoreURL
                case dataStoreUser, dataStorePassword, dataStoreTestQuery, dataStoreLogFile, dataStoreInitConns, dataStoreMaxConns, dataStoreConnUsageLimit, dataStoreLogLevel
                case maxURLLength
                case mailHost, mailHostOverride, log, logLocation, logMaxSize, dataLog, dataLogLocation, dataLogMaxSize, removePageCache, removeTemplateCache, fileTransferFolder, lookInContext, adminGroupID, betaServer
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var configGlossaryInstallationAt: String?
                    var configGlossaryAdminEmail: String?
                    var configGlossaryPoweredBy: String?
                    var configGlossaryPoweredByIcon: String?
                    var configGlossaryStaticPath: String?
                    var templateProcessorClass: String?
                    var templateLoaderClass: String?
                    var templatePath: String?
                    var templateOverridePath: String?
                    var defaultListTemplate: String?
                    var defaultFileTemplate: String?
                    var useJSP: Bool?
                    var jspListTemplate: String?
                    var jspFileTemplate: String?
                    var cachePackageTagsTrack: Int?
                    var cachePackageTagsStore: Int?
                    var cachePackageTagsRefresh: Int?
                    var cacheTemplatesTrack: Int?
                    var cacheTemplatesStore: Int?
                    var cacheTemplatesRefresh: Int?
                    var cachePagesTrack: Int?
                    var cachePagesStore: Int?
                    var cachePagesRefresh: Int?
                    var cachePagesDirtyRead: Int?
                    var searchEngineListTemplate: String?
                    var searchEngineFileTemplate: String?
                    var searchEngineRobotsDB: String?
                    var useDataStore: Bool?
                    var dataStoreClass: String?
                    var redirectionClass: String?
                    var dataStoreName: String?
                    var dataStoreDriver: String?
                    var dataStoreURL: String?
                    var dataStoreUser: String?
                    var dataStorePassword: String?
                    var dataStoreTestQuery: String?
                    var dataStoreLogFile: String?
                    var dataStoreInitConns: Int?
                    var dataStoreMaxConns: Int?
                    var dataStoreConnUsageLimit: Int?
                    var dataStoreLogLevel: String?
                    var maxURLLength: Int?
                    var mailHost: String?
                    var mailHostOverride: String?
                    var log: Int?
                    var logLocation: String?
                    var logMaxSize: String?
                    var dataLog: Int?
                    var dataLogLocation: String?
                    var dataLogMaxSize: String?
                    var removePageCache: String?
                    var removeTemplateCache: String?
                    var fileTransferFolder: String?
                    var lookInContext: Int?
                    var adminGroupID: Int?
                    var betaServer: Bool?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "configGlossaryInstallationAt":
                            configGlossaryInstallationAt = try valueDecoder.decode(String.self)
                        case "configGlossaryAdminEmail":
                            configGlossaryAdminEmail = try valueDecoder.decode(String.self)
                        case "configGlossaryPoweredBy":
                            configGlossaryPoweredBy = try valueDecoder.decode(String.self)
                        case "configGlossaryPoweredByIcon":
                            configGlossaryPoweredByIcon = try valueDecoder.decode(String.self)
                        case "configGlossaryStaticPath":
                            configGlossaryStaticPath = try valueDecoder.decode(String.self)
                        case "templateProcessorClass":
                            templateProcessorClass = try valueDecoder.decode(String.self)
                        case "templateLoaderClass":
                            templateLoaderClass = try valueDecoder.decode(String.self)
                        case "templatePath":
                            templatePath = try valueDecoder.decode(String.self)
                        case "templateOverridePath":
                            templateOverridePath = try valueDecoder.decode(String.self)
                        case "defaultListTemplate":
                            defaultListTemplate = try valueDecoder.decode(String.self)
                        case "defaultFileTemplate":
                            defaultFileTemplate = try valueDecoder.decode(String.self)
                        case "useJSP":
                            useJSP = try valueDecoder.decode(Bool.self)
                        case "jspListTemplate":
                            jspListTemplate = try valueDecoder.decode(String.self)
                        case "jspFileTemplate":
                            jspFileTemplate = try valueDecoder.decode(String.self)
                        case "cachePackageTagsTrack":
                            cachePackageTagsTrack = try valueDecoder.decode(Int.self)
                        case "cachePackageTagsStore":
                            cachePackageTagsStore = try valueDecoder.decode(Int.self)
                        case "cachePackageTagsRefresh":
                            cachePackageTagsRefresh = try valueDecoder.decode(Int.self)
                        case "cacheTemplatesTrack":
                            cacheTemplatesTrack = try valueDecoder.decode(Int.self)
                        case "cacheTemplatesStore":
                            cacheTemplatesStore = try valueDecoder.decode(Int.self)
                        case "cacheTemplatesRefresh":
                            cacheTemplatesRefresh = try valueDecoder.decode(Int.self)
                        case "cachePagesTrack":
                            cachePagesTrack = try valueDecoder.decode(Int.self)
                        case "cachePagesStore":
                            cachePagesStore = try valueDecoder.decode(Int.self)
                        case "cachePagesRefresh":
                            cachePagesRefresh = try valueDecoder.decode(Int.self)
                        case "cachePagesDirtyRead":
                            cachePagesDirtyRead = try valueDecoder.decode(Int.self)
                        case "searchEngineListTemplate":
                            searchEngineListTemplate = try valueDecoder.decode(String.self)
                        case "searchEngineFileTemplate":
                            searchEngineFileTemplate = try valueDecoder.decode(String.self)
                        case "searchEngineRobotsDB":
                            searchEngineRobotsDB = try valueDecoder.decode(String.self)
                        case "useDataStore":
                            useDataStore = try valueDecoder.decode(Bool.self)
                        case "dataStoreClass":
                            dataStoreClass = try valueDecoder.decode(String.self)
                        case "redirectionClass":
                            redirectionClass = try valueDecoder.decode(String.self)
                        case "dataStoreName":
                            dataStoreName = try valueDecoder.decode(String.self)
                        case "dataStoreDriver":
                            dataStoreDriver = try valueDecoder.decode(String.self)
                        case "dataStoreURL":
                            dataStoreURL = try valueDecoder.decode(String.self)
                        case "dataStoreUser":
                            dataStoreUser = try valueDecoder.decode(String.self)
                        case "dataStorePassword":
                            dataStorePassword = try valueDecoder.decode(String.self)
                        case "dataStoreTestQuery":
                            dataStoreTestQuery = try valueDecoder.decode(String.self)
                        case "dataStoreLogFile":
                            dataStoreLogFile = try valueDecoder.decode(String.self)
                        case "dataStoreInitConns":
                            dataStoreInitConns = try valueDecoder.decode(Int.self)
                        case "dataStoreMaxConns":
                            dataStoreMaxConns = try valueDecoder.decode(Int.self)
                        case "dataStoreConnUsageLimit":
                            dataStoreConnUsageLimit = try valueDecoder.decode(Int.self)
                        case "dataStoreLogLevel":
                            dataStoreLogLevel = try valueDecoder.decode(String.self)
                        case "maxURLLength":
                            maxURLLength = try valueDecoder.decode(Int.self)
                        case "mailHost":
                            mailHost = try valueDecoder.decode(String.self)
                        case "mailHostOverride":
                            mailHostOverride = try valueDecoder.decode(String.self)
                        case "log":
                            log = try valueDecoder.decode(Int.self)
                        case "logLocation":
                            logLocation = try valueDecoder.decode(String.self)
                        case "logMaxSize":
                            logMaxSize = try valueDecoder.decode(String.self)
                        case "dataLog":
                            dataLog = try valueDecoder.decode(Int.self)
                        case "dataLogLocation":
                            dataLogLocation = try valueDecoder.decode(String.self)
                        case "dataLogMaxSize":
                            dataLogMaxSize = try valueDecoder.decode(String.self)
                        case "removePageCache":
                            removePageCache = try valueDecoder.decode(String.self)
                        case "removeTemplateCache":
                            removeTemplateCache = try valueDecoder.decode(String.self)
                        case "fileTransferFolder":
                            fileTransferFolder = try valueDecoder.decode(String.self)
                        case "lookInContext":
                            lookInContext = try valueDecoder.decode(Int.self)
                        case "adminGroupID":
                            adminGroupID = try valueDecoder.decode(Int.self)
                        case "betaServer":
                            betaServer = try valueDecoder.decode(Bool.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    return InitParam(
                        configGlossaryInstallationAt: configGlossaryInstallationAt,
                        configGlossaryAdminEmail: configGlossaryAdminEmail,
                        configGlossaryPoweredBy: configGlossaryPoweredBy,
                        configGlossaryPoweredByIcon: configGlossaryPoweredByIcon,
                        configGlossaryStaticPath: configGlossaryStaticPath,
                        templateProcessorClass: templateProcessorClass,
                        templateLoaderClass: templateLoaderClass,
                        templatePath: templatePath,
                        templateOverridePath: templateOverridePath,
                        defaultListTemplate: defaultListTemplate,
                        defaultFileTemplate: defaultFileTemplate,
                        useJSP: useJSP,
                        jspListTemplate: jspListTemplate,
                        jspFileTemplate: jspFileTemplate,
                        cachePackageTagsTrack: cachePackageTagsTrack,
                        cachePackageTagsStore: cachePackageTagsStore,
                        cachePackageTagsRefresh: cachePackageTagsRefresh,
                        cacheTemplatesTrack: cacheTemplatesTrack,
                        cacheTemplatesStore: cacheTemplatesStore,
                        cacheTemplatesRefresh: cacheTemplatesRefresh,
                        cachePagesTrack: cachePagesTrack,
                        cachePagesStore: cachePagesStore,
                        cachePagesRefresh: cachePagesRefresh,
                        cachePagesDirtyRead: cachePagesDirtyRead,
                        searchEngineListTemplate: searchEngineListTemplate,
                        searchEngineFileTemplate: searchEngineFileTemplate,
                        searchEngineRobotsDB: searchEngineRobotsDB,
                        useDataStore: useDataStore,
                        dataStoreClass: dataStoreClass,
                        redirectionClass: redirectionClass,
                        dataStoreName: dataStoreName,
                        dataStoreDriver: dataStoreDriver,
                        dataStoreURL: dataStoreURL,
                        dataStoreUser: dataStoreUser,
                        dataStorePassword: dataStorePassword,
                        dataStoreTestQuery: dataStoreTestQuery,
                        dataStoreLogFile: dataStoreLogFile,
                        dataStoreInitConns: dataStoreInitConns,
                        dataStoreMaxConns: dataStoreMaxConns,
                        dataStoreConnUsageLimit: dataStoreConnUsageLimit,
                        dataStoreLogLevel: dataStoreLogLevel,
                        maxURLLength: maxURLLength,
                        mailHost: mailHost,
                        mailHostOverride: mailHostOverride,
                        log: log,
                        logLocation: logLocation,
                        logMaxSize: logMaxSize,
                        dataLog: dataLog,
                        dataLogLocation: dataLogLocation,
                        dataLogMaxSize: dataLogMaxSize,
                        removePageCache: removePageCache,
                        removeTemplateCache: removeTemplateCache,
                        fileTransferFolder: fileTransferFolder,
                        lookInContext: lookInContext,
                        adminGroupID: adminGroupID,
                        betaServer: betaServer
                    )
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    if let configGlossaryInstallationAt = configGlossaryInstallationAt {
                        try objectEncoder.encode(key: "configGlossaryInstallationAt", value: configGlossaryInstallationAt)
                    }
                    if let configGlossaryAdminEmail = configGlossaryAdminEmail {
                        try objectEncoder.encode(key: "configGlossaryAdminEmail", value: configGlossaryAdminEmail)
                    }
                    if let configGlossaryPoweredBy = configGlossaryPoweredBy {
                        try objectEncoder.encode(key: "configGlossaryPoweredBy", value: configGlossaryPoweredBy)
                    }
                    if let configGlossaryPoweredByIcon = configGlossaryPoweredByIcon {
                        try objectEncoder.encode(key: "configGlossaryPoweredByIcon", value: configGlossaryPoweredByIcon)
                    }
                    if let configGlossaryStaticPath = configGlossaryStaticPath {
                        try objectEncoder.encode(key: "configGlossaryStaticPath", value: configGlossaryStaticPath)
                    }
                    if let templateProcessorClass = templateProcessorClass {
                        try objectEncoder.encode(key: "templateProcessorClass", value: templateProcessorClass)
                    }
                    if let templateLoaderClass = templateLoaderClass {
                        try objectEncoder.encode(key: "templateLoaderClass", value: templateLoaderClass)
                    }
                    if let templatePath = templatePath {
                        try objectEncoder.encode(key: "templatePath", value: templatePath)
                    }
                    if let templateOverridePath = templateOverridePath {
                        try objectEncoder.encode(key: "templateOverridePath", value: templateOverridePath)
                    }
                    if let defaultListTemplate = defaultListTemplate {
                        try objectEncoder.encode(key: "defaultListTemplate", value: defaultListTemplate)
                    }
                    if let defaultFileTemplate = defaultFileTemplate {
                        try objectEncoder.encode(key: "defaultFileTemplate", value: defaultFileTemplate)
                    }
                    if let useJSP = useJSP {
                        try objectEncoder.encode(key: "useJSP", value: useJSP)
                    }
                    if let jspListTemplate = jspListTemplate {
                        try objectEncoder.encode(key: "jspListTemplate", value: jspListTemplate)
                    }
                    if let jspFileTemplate = jspFileTemplate {
                        try objectEncoder.encode(key: "jspFileTemplate", value: jspFileTemplate)
                    }
                    if let cachePackageTagsTrack = cachePackageTagsTrack {
                        try objectEncoder.encode(key: "cachePackageTagsTrack", value: cachePackageTagsTrack)
                    }
                    if let cachePackageTagsStore = cachePackageTagsStore {
                        try objectEncoder.encode(key: "cachePackageTagsStore", value: cachePackageTagsStore)
                    }
                    if let cachePackageTagsRefresh = cachePackageTagsRefresh {
                        try objectEncoder.encode(key: "cachePackageTagsRefresh", value: cachePackageTagsRefresh)
                    }
                    if let cacheTemplatesTrack = cacheTemplatesTrack {
                        try objectEncoder.encode(key: "cacheTemplatesTrack", value: cacheTemplatesTrack)
                    }
                    if let cacheTemplatesStore = cacheTemplatesStore {
                        try objectEncoder.encode(key: "cacheTemplatesStore", value: cacheTemplatesStore)
                    }
                    if let cacheTemplatesRefresh = cacheTemplatesRefresh {
                        try objectEncoder.encode(key: "cacheTemplatesRefresh", value: cacheTemplatesRefresh)
                    }
                    if let cachePagesTrack = cachePagesTrack {
                        try objectEncoder.encode(key: "cachePagesTrack", value: cachePagesTrack)
                    }
                    if let cachePagesStore = cachePagesStore {
                        try objectEncoder.encode(key: "cachePagesStore", value: cachePagesStore)
                    }
                    if let cachePagesRefresh = cachePagesRefresh {
                        try objectEncoder.encode(key: "cachePagesRefresh", value: cachePagesRefresh)
                    }
                    if let cachePagesDirtyRead = cachePagesDirtyRead {
                        try objectEncoder.encode(key: "cachePagesDirtyRead", value: cachePagesDirtyRead)
                    }
                    if let searchEngineListTemplate = searchEngineListTemplate {
                        try objectEncoder.encode(key: "searchEngineListTemplate", value: searchEngineListTemplate)
                    }
                    if let searchEngineFileTemplate = searchEngineFileTemplate {
                        try objectEncoder.encode(key: "searchEngineFileTemplate", value: searchEngineFileTemplate)
                    }
                    if let searchEngineRobotsDB = searchEngineRobotsDB {
                        try objectEncoder.encode(key: "searchEngineRobotsDB", value: searchEngineRobotsDB)
                    }
                    if let useDataStore = useDataStore {
                        try objectEncoder.encode(key: "useDataStore", value: useDataStore)
                    }
                    if let dataStoreClass = dataStoreClass {
                        try objectEncoder.encode(key: "dataStoreClass", value: dataStoreClass)
                    }
                    if let redirectionClass = redirectionClass {
                        try objectEncoder.encode(key: "redirectionClass", value: redirectionClass)
                    }
                    if let dataStoreName = dataStoreName {
                        try objectEncoder.encode(key: "dataStoreName", value: dataStoreName)
                    }
                    if let dataStoreDriver = dataStoreDriver {
                        try objectEncoder.encode(key: "dataStoreDriver", value: dataStoreDriver)
                    }
                    if let dataStoreURL = dataStoreURL {
                        try objectEncoder.encode(key: "dataStoreURL", value: dataStoreURL)
                    }
                    if let dataStoreUser = dataStoreUser {
                        try objectEncoder.encode(key: "dataStoreUser", value: dataStoreUser)
                    }
                    if let dataStorePassword = dataStorePassword {
                        try objectEncoder.encode(key: "dataStorePassword", value: dataStorePassword)
                    }
                    if let dataStoreTestQuery = dataStoreTestQuery {
                        try objectEncoder.encode(key: "dataStoreTestQuery", value: dataStoreTestQuery)
                    }
                    if let dataStoreLogFile = dataStoreLogFile {
                        try objectEncoder.encode(key: "dataStoreLogFile", value: dataStoreLogFile)
                    }
                    if let dataStoreInitConns = dataStoreInitConns {
                        try objectEncoder.encode(key: "dataStoreInitConns", value: dataStoreInitConns)
                    }
                    if let dataStoreMaxConns = dataStoreMaxConns {
                        try objectEncoder.encode(key: "dataStoreMaxConns", value: dataStoreMaxConns)
                    }
                    if let dataStoreConnUsageLimit = dataStoreConnUsageLimit {
                        try objectEncoder.encode(key: "dataStoreConnUsageLimit", value: dataStoreConnUsageLimit)
                    }
                    if let dataStoreLogLevel = dataStoreLogLevel {
                        try objectEncoder.encode(key: "dataStoreLogLevel", value: dataStoreLogLevel)
                    }
                    if let maxURLLength = maxURLLength {
                        try objectEncoder.encode(key: "maxURLLength", value: maxURLLength)
                    }
                    if let mailHost = mailHost {
                        try objectEncoder.encode(key: "mailHost", value: mailHost)
                    }
                    if let mailHostOverride = mailHostOverride {
                        try objectEncoder.encode(key: "mailHostOverride", value: mailHostOverride)
                    }
                    if let log = log {
                        try objectEncoder.encode(key: "log", value: log)
                    }
                    if let logLocation = logLocation {
                        try objectEncoder.encode(key: "logLocation", value: logLocation)
                    }
                    if let logMaxSize = logMaxSize {
                        try objectEncoder.encode(key: "logMaxSize", value: logMaxSize)
                    }
                    if let dataLog = dataLog {
                        try objectEncoder.encode(key: "dataLog", value: dataLog)
                    }
                    if let dataLogLocation = dataLogLocation {
                        try objectEncoder.encode(key: "dataLogLocation", value: dataLogLocation)
                    }
                    if let dataLogMaxSize = dataLogMaxSize {
                        try objectEncoder.encode(key: "dataLogMaxSize", value: dataLogMaxSize)
                    }
                    if let removePageCache = removePageCache {
                        try objectEncoder.encode(key: "removePageCache", value: removePageCache)
                    }
                    if let removeTemplateCache = removeTemplateCache {
                        try objectEncoder.encode(key: "removeTemplateCache", value: removeTemplateCache)
                    }
                    if let fileTransferFolder = fileTransferFolder {
                        try objectEncoder.encode(key: "fileTransferFolder", value: fileTransferFolder)
                    }
                    if let lookInContext = lookInContext {
                        try objectEncoder.encode(key: "lookInContext", value: lookInContext)
                    }
                    if let adminGroupID = adminGroupID {
                        try objectEncoder.encode(key: "adminGroupID", value: adminGroupID)
                    }
                    if let betaServer = betaServer {
                        try objectEncoder.encode(key: "betaServer", value: betaServer)
                    }
                }
            }
        }

        struct ServletMapping: Codable, JSONCodable, Equatable {
            let cofaxCDS, cofaxEmail, cofaxAdmin, fileServlet: String
            let cofaxTools: String

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var cofaxCDS: String?
                    var cofaxEmail: String?
                    var cofaxAdmin: String?
                    var fileServlet: String?
                    var cofaxTools: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "cofaxCDS":
                            cofaxCDS = try valueDecoder.decode(String.self)
                        case "cofaxEmail":
                            cofaxEmail = try valueDecoder.decode(String.self)
                        case "cofaxAdmin":
                            cofaxAdmin = try valueDecoder.decode(String.self)
                        case "fileServlet":
                            fileServlet = try valueDecoder.decode(String.self)
                        case "cofaxTools":
                            cofaxTools = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let cofaxCDS = cofaxCDS else { throw CodingError.keyNotFound("cofaxCDS") }
                    guard let cofaxEmail = cofaxEmail else { throw CodingError.keyNotFound("cofaxEmail") }
                    guard let cofaxAdmin = cofaxAdmin else { throw CodingError.keyNotFound("cofaxAdmin") }
                    guard let fileServlet = fileServlet else { throw CodingError.keyNotFound("fileServlet") }
                    guard let cofaxTools = cofaxTools else { throw CodingError.keyNotFound("cofaxTools") }

                    return ServletMapping(cofaxCDS: cofaxCDS, cofaxEmail: cofaxEmail, cofaxAdmin: cofaxAdmin, fileServlet: fileServlet, cofaxTools: cofaxTools)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "cofaxCDS", value: cofaxCDS)
                    try objectEncoder.encode(key: "cofaxEmail", value: cofaxEmail)
                    try objectEncoder.encode(key: "cofaxAdmin", value: cofaxAdmin)
                    try objectEncoder.encode(key: "fileServlet", value: fileServlet)
                    try objectEncoder.encode(key: "cofaxTools", value: cofaxTools)
                }
            }
        }

        struct Taglib: Codable, JSONCodable, Equatable {
            let taglibURI, taglibLocation: String

            enum CodingKeys: String, CodingKey {
                case taglibURI = "taglib-uri"
                case taglibLocation = "taglib-location"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var taglibURI: String?
                    var taglibLocation: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "taglib-uri":
                            taglibURI = try valueDecoder.decode(String.self)
                        case "taglib-location":
                            taglibLocation = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let taglibURI = taglibURI else { throw CodingError.keyNotFound("taglibURI") }
                    guard let taglibLocation = taglibLocation else { throw CodingError.keyNotFound("taglibLocation") }

                    return Taglib(taglibURI: taglibURI, taglibLocation: taglibLocation)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.taglibURI.stringValue, value: taglibURI)
                    try objectEncoder.encode(key: CodingKeys.taglibLocation.stringValue, value: taglibLocation)
                }
            }
        }
    }
}

extension JSONPass {
    struct Test5: Codable, JSONCodable, Equatable {
        let image: Image

        enum CodingKeys: String, CodingKey {
            case image = "Image"
        }

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var image: Image?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "Image":
                        image = try valueDecoder.decode(Image.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let image = image else {
                    throw CodingError.keyNotFound("image")
                }

                return Test5(image: image)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: CodingKeys.image.stringValue, value: image)
            }
        }

        struct Image: Codable, JSONCodable, Equatable {
            let width, height: Int
            let title: String
            let thumbnail: Thumbnail
            let ids: [Int]

            enum CodingKeys: String,  CodingKey {
                case width = "Width"
                case height = "Height"
                case title = "Title"
                case thumbnail = "Thumbnail"
                case ids = "IDs"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var width: Int?
                    var height: Int?
                    var title: String?
                    var thumbnail: Thumbnail?
                    var ids: [Int]?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "Width":
                            width = try valueDecoder.decode(Int.self)
                        case "Height":
                            height = try valueDecoder.decode(Int.self)
                        case "Title":
                            title = try valueDecoder.decode(String.self)
                        case "Thumbnail":
                            thumbnail = try valueDecoder.decode(Thumbnail.self)
                        case "IDs":
                            ids = try valueDecoder.decode([Int].self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let width = width else { throw CodingError.keyNotFound("width") }
                    guard let height = height else { throw CodingError.keyNotFound("height") }
                    guard let title = title else { throw CodingError.keyNotFound("title") }
                    guard let thumbnail = thumbnail else { throw CodingError.keyNotFound("thumbnail") }
                    guard let ids = ids else { throw CodingError.keyNotFound("ids") }

                    return Image(width: width, height: height, title: title, thumbnail: thumbnail, ids: ids)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.width.stringValue, value: width)
                    try objectEncoder.encode(key: CodingKeys.height.stringValue, value: height)
                    try objectEncoder.encode(key: CodingKeys.title.stringValue, value: title)
                    try objectEncoder.encode(key: CodingKeys.thumbnail.stringValue, value: thumbnail)
                    try objectEncoder.encode(key: CodingKeys.ids.stringValue, value: ids)
                }
            }
        }

        struct Thumbnail: Codable, JSONCodable, Equatable {
            let url: String
            let height: Int
            let width: String

            enum CodingKeys: String, CodingKey {
                case url = "Url"
                case height = "Height"
                case width = "Width"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var url: String?
                    var height: Int?
                    var width: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "Url":
                            url = try valueDecoder.decode(String.self)
                        case "Height":
                            height = try valueDecoder.decode(Int.self)
                        case "Width":
                            width = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let url = url else { throw CodingError.keyNotFound("url") }
                    guard let height = height else { throw CodingError.keyNotFound("height") }
                    guard let width = width else { throw CodingError.keyNotFound("width") }

                    return Thumbnail(url: url, height: height, width: width)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.url.stringValue, value: url)
                    try objectEncoder.encode(key: CodingKeys.height.stringValue, value: height)
                    try objectEncoder.encode(key: CodingKeys.width.stringValue, value: width)
                }
            }
        }
    }
}

extension JSONPass {
    typealias Test6 = [Test6Element]

    struct Test6Element: Codable, JSONCodable, Equatable {
        let precision: String
        let latitude, longitude: Double
        let address, city, state, zip: String
        let country: String

        enum CodingKeys: String, CodingKey {
            case precision
            case latitude = "Latitude"
            case longitude = "Longitude"
            case address = "Address"
            case city = "City"
            case state = "State"
            case zip = "Zip"
            case country = "Country"
        }

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var precision: String?
                var latitude: Double?
                var longitude: Double?
                var address: String?
                var city: String?
                var state: String?
                var zip: String?
                var country: String?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "precision":
                        precision = try valueDecoder.decode(String.self)
                    case "Latitude":
                        latitude = try valueDecoder.decode(Double.self)
                    case "Longitude":
                        longitude = try valueDecoder.decode(Double.self)
                    case "Address":
                        address = try valueDecoder.decode(String.self)
                    case "City":
                        city = try valueDecoder.decode(String.self)
                    case "State":
                        state = try valueDecoder.decode(String.self)
                    case "Zip":
                        zip = try valueDecoder.decode(String.self)
                    case "Country":
                        country = try valueDecoder.decode(String.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let precision = precision else { throw CodingError.keyNotFound("precision") }
                guard let latitude = latitude else { throw CodingError.keyNotFound("latitude") }
                guard let longitude = longitude else { throw CodingError.keyNotFound("longitude") }
                guard let address = address else { throw CodingError.keyNotFound("address") }
                guard let city = city else { throw CodingError.keyNotFound("city") }
                guard let state = state else { throw CodingError.keyNotFound("state") }
                guard let zip = zip else { throw CodingError.keyNotFound("zip") }
                guard let country = country else { throw CodingError.keyNotFound("country") }

                return Test6Element(precision: precision, latitude: latitude, longitude: longitude, address: address, city: city, state: state, zip: zip, country: country)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: CodingKeys.precision.stringValue, value: precision)
                try objectEncoder.encode(key: CodingKeys.latitude.stringValue, value: latitude)
                try objectEncoder.encode(key: CodingKeys.longitude.stringValue, value: longitude)
                try objectEncoder.encode(key: CodingKeys.address.stringValue, value: address)
                try objectEncoder.encode(key: CodingKeys.city.stringValue, value: city)
                try objectEncoder.encode(key: CodingKeys.state.stringValue, value: state)
                try objectEncoder.encode(key: CodingKeys.zip.stringValue, value: zip)
                try objectEncoder.encode(key: CodingKeys.country.stringValue, value: country)
            }
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            guard lhs.precision == rhs.precision, lhs.address == rhs.address, lhs.city == rhs.city, lhs.zip == rhs.zip, lhs.country == rhs.country else {
                return false
            }
            guard (lhs.longitude - rhs.longitude).magnitude <= 1e-10 else {
                return false
            }
            guard (lhs.latitude - rhs.latitude).magnitude <= 1e-10 else {
                return false
            }
            return true
        }
    }
}

extension JSONPass {
    struct Test7: Codable, JSONCodable, Equatable {
        let menu: Menu

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var menu: Menu?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "menu":
                        menu = try valueDecoder.decode(Menu.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let menu = menu else {
                    throw CodingError.keyNotFound("menu")
                }

                return Test7(menu: menu)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: "menu", value: menu)
            }
        }

        struct Menu: Codable, JSONCodable, Equatable {
            let header: String
            let items: [Item]

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var header: String?
                    var items: [Item]?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "header":
                            header = try valueDecoder.decode(String.self)
                        case "items":
                            items = try valueDecoder.decode([Item].self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let header = header else { throw CodingError.keyNotFound("header") }
                    guard let items = items else { throw CodingError.keyNotFound("items") }

                    return Menu(header: header, items: items)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "header", value: header)
                    try objectEncoder.encode(key: "items", value: items)
                }
            }
        }

        struct Item: Codable, JSONCodable, Equatable {
            let id: String
            let label: String?

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var id: String?
                    var label: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "id":
                            id = try valueDecoder.decode(String.self)
                        case "label":
                            label = try valueDecoder.decode(String?.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let id = id else { throw CodingError.keyNotFound("id") }

                    return Item(id: id, label: label)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "id", value: id)
                    if let label = label {
                        try objectEncoder.encode(key: "label", value: label)
                    }
                }
            }
        }
    }
}

extension JSONPass {
    typealias Test8 = [[[[[[[[[[[[[[[[[[[String]]]]]]]]]]]]]]]]]]]
}

extension JSONPass {
    struct Test9: Codable, JSONCodable, Equatable {
        let objects : [AnyHashable]
        
        init(objects: [AnyHashable]) {
            self.objects = objects
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var decodedObjects = [AnyHashable]()

            decodedObjects.append(try container.decode(String.self))
            decodedObjects.append(try container.decode([String:[String]].self))
            decodedObjects.append(try container.decode([String:String].self))
            decodedObjects.append(try container.decode([String].self))
            decodedObjects.append(try container.decode(Int.self))
            decodedObjects.append(try container.decode(Bool.self))
            decodedObjects.append(try container.decode(Bool.self))
            if try container.decodeNil() {
                decodedObjects.append("<null>")
            }
            decodedObjects.append(try container.decode(SpecialCases.self))
            decodedObjects.append(try container.decode(Float.self))
            decodedObjects.append(try container.decode(Float.self))
            decodedObjects.append(try container.decode(Float.self))
            decodedObjects.append(try container.decode(Int.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(Double.self))
            decodedObjects.append(try container.decode(String.self))

            self.objects = decodedObjects
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            try container.encode(objects[ 0] as! String)
            try container.encode(objects[ 1] as! [String:[String]])
            try container.encode(objects[ 2] as! [String:String])
            try container.encode(objects[ 3] as! [String])
            try container.encode(objects[ 4] as! Int)
            try container.encode(objects[ 5] as! Bool)
            try container.encode(objects[ 6] as! Bool)
            try container.encodeNil()
            try container.encode(objects[ 8] as! SpecialCases)
            try container.encode(objects[ 9] as! Float)
            try container.encode(objects[10] as! Float)
            try container.encode(objects[11] as! Float)
            try container.encode(objects[12] as! Int)
            try container.encode(objects[13] as! Double)
            try container.encode(objects[14] as! Double)
            try container.encode(objects[15] as! Double)
            try container.encode(objects[16] as! Double)
            try container.encode(objects[17] as! Double)
            try container.encode(objects[18] as! Double)
            try container.encode(objects[19] as! String)
        }

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeArray { arrayDecoder throws(CodingError.Decoding) in
                var decodedObjects = [AnyHashable]()

                decodedObjects.append(try arrayDecoder.decodeRequiredNext(String.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext([String:[String]].self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext([String:String].self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext([String].self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Int.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Bool.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Bool.self))
                
                try arrayDecoder.decodeRequiredNext { elementDecoder throws(CodingError.Decoding) in
                    if try elementDecoder.decodeNil() {
                        decodedObjects.append("<null>")
                    }
                    return ()
                }
                
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(SpecialCases.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Float.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Float.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Float.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Int.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Double.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Double.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Double.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Double.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Double.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(Double.self))
                decodedObjects.append(try arrayDecoder.decodeRequiredNext(String.self))

                return Test9(objects: decodedObjects)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeArray { sequenceEncoder throws(CodingError.Encoding) in
                try sequenceEncoder.encode(objects[ 0] as! String)
                try sequenceEncoder.encode(objects[ 1] as! [String:[String]])
                try sequenceEncoder.encode(objects[ 2] as! [String:String])
                try sequenceEncoder.encode(objects[ 3] as! [String])
                try sequenceEncoder.encode(objects[ 4] as! Int)
                try sequenceEncoder.encode(objects[ 5] as! Bool)
                try sequenceEncoder.encode(objects[ 6] as! Bool)
                try sequenceEncoder.encode(String?.none)
                try sequenceEncoder.encode(objects[ 8] as! SpecialCases)
                try sequenceEncoder.encode(objects[ 9] as! Float)
                try sequenceEncoder.encode(objects[10] as! Float)
                try sequenceEncoder.encode(objects[11] as! Float)
                try sequenceEncoder.encode(objects[12] as! Int)
                try sequenceEncoder.encode(objects[13] as! Double)
                try sequenceEncoder.encode(objects[14] as! Double)
                try sequenceEncoder.encode(objects[15] as! Double)
                try sequenceEncoder.encode(objects[16] as! Double)
                try sequenceEncoder.encode(objects[17] as! Double)
                try sequenceEncoder.encode(objects[18] as! Double)
                try sequenceEncoder.encode(objects[19] as! String)
            }
        }

        struct SpecialCases : Codable, JSONCodable, Hashable {
            let integer : UInt64
            let real : Double
            let e : Double
            let E : Double
            let empty_key : Double
            let zero : UInt8
            let one : UInt8
            let space : String
            let quote : String
            let backslash : String
            let controls : String
            let slash : String
            let alpha : String
            let ALPHA : String
            let digit : String
            let _0123456789 : String
            let special : String
            let hex: String
            let `true` : Bool
            let `false` : Bool
            let null : Bool?
            let array : [String]
            let object : [String:String]
            let address : String
            let url : String
            let comment : String
            let special_sequences_key : String
            let spaced : [Int]
            let compact : [Int]
            let jsontext : String
            let quotes : String
            let escapedKey : String

            enum CodingKeys: String, CodingKey {
                case integer
                case real
                case e
                case E
                case empty_key = ""
                case zero
                case one
                case space
                case quote
                case backslash
                case controls
                case slash
                case alpha
                case ALPHA
                case digit
                case _0123456789 = "0123456789"
                case special
                case hex
                case `true`
                case `false`
                case null
                case array
                case object
                case address
                case url
                case comment
                case special_sequences_key = "# -- --> */"
                case spaced = " s p a c e d "
                case compact
                case jsontext
                case quotes
                case escapedKey = "/\\\"\u{CAFE}\u{BABE}\u{AB98}\u{FCDE}\u{bcda}\u{ef4A}\u{08}\u{0C}\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var integer: UInt64?
                    var real: Double?
                    var e: Double?
                    var E: Double?
                    var empty_key: Double?
                    var zero: UInt8?
                    var one: UInt8?
                    var space: String?
                    var quote: String?
                    var backslash: String?
                    var controls: String?
                    var slash: String?
                    var alpha: String?
                    var ALPHA: String?
                    var digit: String?
                    var _0123456789: String?
                    var special: String?
                    var hex: String?
                    var `true`: Bool?
                    var `false`: Bool?
                    var null: Bool?
                    var array: [String]?
                    var object: [String:String]?
                    var address: String?
                    var url: String?
                    var comment: String?
                    var special_sequences_key: String?
                    var spaced: [Int]?
                    var compact: [Int]?
                    var jsontext: String?
                    var quotes: String?
                    var escapedKey: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "integer":
                            integer = try valueDecoder.decode(UInt64.self)
                        case "real":
                            real = try valueDecoder.decode(Double.self)
                        case "e":
                            e = try valueDecoder.decode(Double.self)
                        case "E":
                            E = try valueDecoder.decode(Double.self)
                        case "":
                            empty_key = try valueDecoder.decode(Double.self)
                        case "zero":
                            zero = try valueDecoder.decode(UInt8.self)
                        case "one":
                            one = try valueDecoder.decode(UInt8.self)
                        case "space":
                            space = try valueDecoder.decode(String.self)
                        case "quote":
                            quote = try valueDecoder.decode(String.self)
                        case "backslash":
                            backslash = try valueDecoder.decode(String.self)
                        case "controls":
                            controls = try valueDecoder.decode(String.self)
                        case "slash":
                            slash = try valueDecoder.decode(String.self)
                        case "alpha":
                            alpha = try valueDecoder.decode(String.self)
                        case "ALPHA":
                            ALPHA = try valueDecoder.decode(String.self)
                        case "digit":
                            digit = try valueDecoder.decode(String.self)
                        case "0123456789":
                            _0123456789 = try valueDecoder.decode(String.self)
                        case "special":
                            special = try valueDecoder.decode(String.self)
                        case "hex":
                            hex = try valueDecoder.decode(String.self)
                        case "true":
                            `true` = try valueDecoder.decode(Bool.self)
                        case "false":
                            `false` = try valueDecoder.decode(Bool.self)
                        case "null":
                            null = try valueDecoder.decode(Bool?.self)
                        case "array":
                            array = try valueDecoder.decode([String].self)
                        case "object":
                            object = try valueDecoder.decode([String:String].self)
                        case "address":
                            address = try valueDecoder.decode(String.self)
                        case "url":
                            url = try valueDecoder.decode(String.self)
                        case "comment":
                            comment = try valueDecoder.decode(String.self)
                        case "# -- --> */":
                            special_sequences_key = try valueDecoder.decode(String.self)
                        case " s p a c e d ":
                            spaced = try valueDecoder.decode([Int].self)
                        case "compact":
                            compact = try valueDecoder.decode([Int].self)
                        case "jsontext":
                            jsontext = try valueDecoder.decode(String.self)
                        case "quotes":
                            quotes = try valueDecoder.decode(String.self)
                        case "/\\\"\u{CAFE}\u{BABE}\u{AB98}\u{FCDE}\u{bcda}\u{ef4A}\u{08}\u{0C}\n\r\t`1~!@#$%^&*()_+-=[]{}|;:',./<>?":
                            escapedKey = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let integer = integer else { throw CodingError.keyNotFound("integer") }
                    guard let real = real else { throw CodingError.keyNotFound("real") }
                    guard let e = e else { throw CodingError.keyNotFound("e") }
                    guard let E = E else { throw CodingError.keyNotFound("E") }
                    guard let empty_key = empty_key else { throw CodingError.keyNotFound("empty_key") }
                    guard let zero = zero else { throw CodingError.keyNotFound("zero") }
                    guard let one = one else { throw CodingError.keyNotFound("one") }
                    guard let space = space else { throw CodingError.keyNotFound("space") }
                    guard let quote = quote else { throw CodingError.keyNotFound("quote") }
                    guard let backslash = backslash else { throw CodingError.keyNotFound("backslash") }
                    guard let controls = controls else { throw CodingError.keyNotFound("controls") }
                    guard let slash = slash else { throw CodingError.keyNotFound("slash") }
                    guard let alpha = alpha else { throw CodingError.keyNotFound("alpha") }
                    guard let ALPHA = ALPHA else { throw CodingError.keyNotFound("ALPHA") }
                    guard let digit = digit else { throw CodingError.keyNotFound("digit") }
                    guard let _0123456789 = _0123456789 else { throw CodingError.keyNotFound("_0123456789") }
                    guard let special = special else { throw CodingError.keyNotFound("special") }
                    guard let hex = hex else { throw CodingError.keyNotFound("hex") }
                    guard let `true` = `true` else { throw CodingError.keyNotFound("true") }
                    guard let `false` = `false` else { throw CodingError.keyNotFound("false") }
                    guard let array = array else { throw CodingError.keyNotFound("array") }
                    guard let object = object else { throw CodingError.keyNotFound("object") }
                    guard let address = address else { throw CodingError.keyNotFound("address") }
                    guard let url = url else { throw CodingError.keyNotFound("url") }
                    guard let comment = comment else { throw CodingError.keyNotFound("comment") }
                    guard let special_sequences_key = special_sequences_key else { throw CodingError.keyNotFound("special_sequences_key") }
                    guard let spaced = spaced else { throw CodingError.keyNotFound("spaced") }
                    guard let compact = compact else { throw CodingError.keyNotFound("compact") }
                    guard let jsontext = jsontext else { throw CodingError.keyNotFound("jsontext") }
                    guard let quotes = quotes else { throw CodingError.keyNotFound("quotes") }
                    guard let escapedKey = escapedKey else { throw CodingError.keyNotFound("escapedKey") }

                    return SpecialCases(
                        integer: integer,
                        real: real,
                        e: e,
                        E: E,
                        empty_key: empty_key,
                        zero: zero,
                        one: one,
                        space: space,
                        quote: quote,
                        backslash: backslash,
                        controls: controls,
                        slash: slash,
                        alpha: alpha,
                        ALPHA: ALPHA,
                        digit: digit,
                        _0123456789: _0123456789,
                        special: special,
                        hex: hex,
                        true: `true`,
                        false: `false`,
                        null: null,
                        array: array,
                        object: object,
                        address: address,
                        url: url,
                        comment: comment,
                        special_sequences_key: special_sequences_key,
                        spaced: spaced,
                        compact: compact,
                        jsontext: jsontext,
                        quotes: quotes,
                        escapedKey: escapedKey
                    )
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.integer.stringValue, value: integer)
                    try objectEncoder.encode(key: CodingKeys.real.stringValue, value: real)
                    try objectEncoder.encode(key: CodingKeys.e.stringValue, value: e)
                    try objectEncoder.encode(key: CodingKeys.E.stringValue, value: E)
                    try objectEncoder.encode(key: CodingKeys.empty_key.stringValue, value: empty_key)
                    try objectEncoder.encode(key: CodingKeys.zero.stringValue, value: zero)
                    try objectEncoder.encode(key: CodingKeys.one.stringValue, value: one)
                    try objectEncoder.encode(key: CodingKeys.space.stringValue, value: space)
                    try objectEncoder.encode(key: CodingKeys.quote.stringValue, value: quote)
                    try objectEncoder.encode(key: CodingKeys.backslash.stringValue, value: backslash)
                    try objectEncoder.encode(key: CodingKeys.controls.stringValue, value: controls)
                    try objectEncoder.encode(key: CodingKeys.slash.stringValue, value: slash)
                    try objectEncoder.encode(key: CodingKeys.alpha.stringValue, value: alpha)
                    try objectEncoder.encode(key: CodingKeys.ALPHA.stringValue, value: ALPHA)
                    try objectEncoder.encode(key: CodingKeys.digit.stringValue, value: digit)
                    try objectEncoder.encode(key: CodingKeys._0123456789.stringValue, value: _0123456789)
                    try objectEncoder.encode(key: CodingKeys.special.stringValue, value: special)
                    try objectEncoder.encode(key: CodingKeys.hex.stringValue, value: hex)
                    try objectEncoder.encode(key: CodingKeys.true.stringValue, value: `true`)
                    try objectEncoder.encode(key: CodingKeys.false.stringValue, value: `false`)
                    try objectEncoder.encode(key: CodingKeys.null.stringValue, value: null)
                    try objectEncoder.encode(key: CodingKeys.array.stringValue, value: array)
                    try objectEncoder.encode(key: CodingKeys.object.stringValue, value: object)
                    try objectEncoder.encode(key: CodingKeys.address.stringValue, value: address)
                    try objectEncoder.encode(key: CodingKeys.url.stringValue, value: url)
                    try objectEncoder.encode(key: CodingKeys.comment.stringValue, value: comment)
                    try objectEncoder.encode(key: CodingKeys.special_sequences_key.stringValue, value: special_sequences_key)
                    try objectEncoder.encode(key: CodingKeys.spaced.stringValue, value: spaced)
                    try objectEncoder.encode(key: CodingKeys.compact.stringValue, value: compact)
                    try objectEncoder.encode(key: CodingKeys.jsontext.stringValue, value: jsontext)
                    try objectEncoder.encode(key: CodingKeys.quotes.stringValue, value: quotes)
                    try objectEncoder.encode(key: CodingKeys.escapedKey.stringValue, value: escapedKey)
                }
            }
        }
    }
}

extension JSONPass {
    typealias Test10 = [String:[String:String]]
    typealias Test11 = [String:String]
}

extension JSONPass {
    struct Test12: Codable, JSONCodable, Equatable {
        let query: Query

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var query: Query?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "query":
                        query = try valueDecoder.decode(Query.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let query = query else {
                    throw CodingError.keyNotFound("query")
                }

                return Test12(query: query)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: "query", value: query)
            }
        }

        struct Query: Codable, JSONCodable, Equatable {
            let pages: Pages

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var pages: Pages?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "pages":
                            pages = try valueDecoder.decode(Pages.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let pages = pages else {
                        throw CodingError.keyNotFound("pages")
                    }

                    return Query(pages: pages)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "pages", value: pages)
                }
            }
        }

        struct Pages: Codable, JSONCodable, Equatable {
            let the80348: The80348

            enum CodingKeys: String, CodingKey {
                case the80348 = "80348"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var the80348: The80348?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "80348":
                            the80348 = try valueDecoder.decode(The80348.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let the80348 = the80348 else {
                        throw CodingError.keyNotFound("the80348")
                    }

                    return Pages(the80348: the80348)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.the80348.stringValue, value: the80348)
                }
            }
        }

        struct The80348: Codable, JSONCodable, Equatable {
            let pageid, ns: Int
            let title: String
            let langlinks: [Langlink]

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var pageid: Int?
                    var ns: Int?
                    var title: String?
                    var langlinks: [Langlink]?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "pageid":
                            pageid = try valueDecoder.decode(Int.self)
                        case "ns":
                            ns = try valueDecoder.decode(Int.self)
                        case "title":
                            title = try valueDecoder.decode(String.self)
                        case "langlinks":
                            langlinks = try valueDecoder.decode([Langlink].self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let pageid = pageid else { throw CodingError.keyNotFound("pageid") }
                    guard let ns = ns else { throw CodingError.keyNotFound("ns") }
                    guard let title = title else { throw CodingError.keyNotFound("title") }
                    guard let langlinks = langlinks else { throw CodingError.keyNotFound("langlinks") }

                    return The80348(pageid: pageid, ns: ns, title: title, langlinks: langlinks)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "pageid", value: pageid)
                    try objectEncoder.encode(key: "ns", value: ns)
                    try objectEncoder.encode(key: "title", value: title)
                    try objectEncoder.encode(key: "langlinks", value: langlinks)
                }
            }
        }

        struct Langlink: Codable, JSONCodable, Equatable {
            let lang, asterisk: String

            enum CodingKeys: String, CodingKey {
                case lang
                case asterisk = "*"
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var lang: String?
                    var asterisk: String?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "lang":
                            lang = try valueDecoder.decode(String.self)
                        case "*":
                            asterisk = try valueDecoder.decode(String.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let lang = lang else { throw CodingError.keyNotFound("lang") }
                    guard let asterisk = asterisk else { throw CodingError.keyNotFound("asterisk") }

                    return Langlink(lang: lang, asterisk: asterisk)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.lang.stringValue, value: lang)
                    try objectEncoder.encode(key: CodingKeys.asterisk.stringValue, value: asterisk)
                }
            }
        }
    }
}

extension JSONPass {
    typealias Test13 = [String:Int]
    typealias Test14 = [String:[String:[String:String]]]
}

extension JSONPass {
    struct Test15: Codable, JSONCodable, Equatable {
        let attached: Bool
        let klass: String
        let errors: [String:[String]]
        let gid: Int
        let id: ID
        let mpid, name: String
        let properties: Properties
        let state: State
        let type: String
        let version: Int

        enum CodingKeys: String, CodingKey {
            case attached
            case klass = "class"
            case errors, gid, id, mpid, name, properties, state, type, version
        }

        static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
            return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                var attached: Bool?
                var klass: String?
                var errors: [String:[String]]?
                var gid: Int?
                var id: ID?
                var mpid: String?
                var name: String?
                var properties: Properties?
                var state: State?
                var type: String?
                var version: Int?

                try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                    switch key {
                    case "attached":
                        attached = try valueDecoder.decode(Bool.self)
                    case "class":
                        klass = try valueDecoder.decode(String.self)
                    case "errors":
                        errors = try valueDecoder.decode([String:[String]].self)
                    case "gid":
                        gid = try valueDecoder.decode(Int.self)
                    case "id":
                        id = try valueDecoder.decode(ID.self)
                    case "mpid":
                        mpid = try valueDecoder.decode(String.self)
                    case "name":
                        name = try valueDecoder.decode(String.self)
                    case "properties":
                        properties = try valueDecoder.decode(Properties.self)
                    case "state":
                        state = try valueDecoder.decode(State.self)
                    case "type":
                        type = try valueDecoder.decode(String.self)
                    case "version":
                        version = try valueDecoder.decode(Int.self)
                    default:
                        break // Skip unknown fields
                    }
                    return false
                }

                guard let attached = attached else { throw CodingError.keyNotFound("attached") }
                guard let klass = klass else { throw CodingError.keyNotFound("klass") }
                guard let errors = errors else { throw CodingError.keyNotFound("errors") }
                guard let gid = gid else { throw CodingError.keyNotFound("gid") }
                guard let id = id else { throw CodingError.keyNotFound("id") }
                guard let mpid = mpid else { throw CodingError.keyNotFound("mpid") }
                guard let name = name else { throw CodingError.keyNotFound("name") }
                guard let properties = properties else { throw CodingError.keyNotFound("properties") }
                guard let state = state else { throw CodingError.keyNotFound("state") }
                guard let type = type else { throw CodingError.keyNotFound("type") }
                guard let version = version else { throw CodingError.keyNotFound("version") }

                return Test15(attached: attached, klass: klass, errors: errors, gid: gid, id: id, mpid: mpid, name: name, properties: properties, state: state, type: type, version: version)
            }
        }

        func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
            try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                try objectEncoder.encode(key: CodingKeys.attached.stringValue, value: attached)
                try objectEncoder.encode(key: CodingKeys.klass.stringValue, value: klass)
                try objectEncoder.encode(key: CodingKeys.errors.stringValue, value: errors)
                try objectEncoder.encode(key: CodingKeys.gid.stringValue, value: gid)
                try objectEncoder.encode(key: CodingKeys.id.stringValue, value: id)
                try objectEncoder.encode(key: CodingKeys.mpid.stringValue, value: mpid)
                try objectEncoder.encode(key: CodingKeys.name.stringValue, value: name)
                try objectEncoder.encode(key: CodingKeys.properties.stringValue, value: properties)
                try objectEncoder.encode(key: CodingKeys.state.stringValue, value: state)
                try objectEncoder.encode(key: CodingKeys.type.stringValue, value: type)
                try objectEncoder.encode(key: CodingKeys.version.stringValue, value: version)
            }
        }

        struct ID: Codable, JSONCodable, Equatable {
            let klass: String
            let inc: Int
            let machine: Int
            let new: Bool
            let time: UInt64
            let timeSecond: UInt64

            enum CodingKeys: String, CodingKey {
                case klass = "class"
                case inc, machine, new, time, timeSecond
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var klass: String?
                    var inc: Int?
                    var machine: Int?
                    var new: Bool?
                    var time: UInt64?
                    var timeSecond: UInt64?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "class":
                            klass = try valueDecoder.decode(String.self)
                        case "inc":
                            inc = try valueDecoder.decode(Int.self)
                        case "machine":
                            machine = try valueDecoder.decode(Int.self)
                        case "new":
                            new = try valueDecoder.decode(Bool.self)
                        case "time":
                            time = try valueDecoder.decode(UInt64.self)
                        case "timeSecond":
                            timeSecond = try valueDecoder.decode(UInt64.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let klass = klass else { throw CodingError.keyNotFound("klass") }
                    guard let inc = inc else { throw CodingError.keyNotFound("inc") }
                    guard let machine = machine else { throw CodingError.keyNotFound("machine") }
                    guard let new = new else { throw CodingError.keyNotFound("new") }
                    guard let time = time else { throw CodingError.keyNotFound("time") }
                    guard let timeSecond = timeSecond else { throw CodingError.keyNotFound("timeSecond") }

                    return ID(klass: klass, inc: inc, machine: machine, new: new, time: time, timeSecond: timeSecond)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.klass.stringValue, value: klass)
                    try objectEncoder.encode(key: CodingKeys.inc.stringValue, value: inc)
                    try objectEncoder.encode(key: CodingKeys.machine.stringValue, value: machine)
                    try objectEncoder.encode(key: CodingKeys.new.stringValue, value: new)
                    try objectEncoder.encode(key: CodingKeys.time.stringValue, value: time)
                    try objectEncoder.encode(key: CodingKeys.timeSecond.stringValue, value: timeSecond)
                }
            }
        }

        final class Properties: Codable, JSONCodable, Equatable {
            let mpid, type: String
            let dbo: DBO?
            let gid: Int
            let name: String?
            let state: State?
            let apiTimestamp: String?
            let gatewayTimestamp: String?
            let eventData: [String:Float]?

            init(mpid: String, type: String, dbo: DBO?, gid: Int, name: String?, state: State?, apiTimestamp: String?, gatewayTimestamp: String?, eventData: [String:Float]?) {
                self.mpid = mpid
                self.type = type
                self.dbo = dbo
                self.gid = gid
                self.name = name
                self.state = state
                self.apiTimestamp = apiTimestamp
                self.gatewayTimestamp = gatewayTimestamp
                self.eventData = eventData
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var mpid: String?
                    var type: String?
                    var dbo: DBO?
                    var gid: Int?
                    var name: String?
                    var state: State?
                    var apiTimestamp: String?
                    var gatewayTimestamp: String?
                    var eventData: [String:Float]?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "mpid":
                            mpid = try valueDecoder.decode(String.self)
                        case "type":
                            type = try valueDecoder.decode(String.self)
                        case "dbo":
                            dbo = try valueDecoder.decode(DBO?.self)
                        case "gid":
                            gid = try valueDecoder.decode(Int.self)
                        case "name":
                            name = try valueDecoder.decode(String?.self)
                        case "state":
                            state = try valueDecoder.decode(State?.self)
                        case "apiTimestamp":
                            apiTimestamp = try valueDecoder.decode(String?.self)
                        case "gatewayTimestamp":
                            gatewayTimestamp = try valueDecoder.decode(String?.self)
                        case "eventData":
                            eventData = try valueDecoder.decode([String:Float]?.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let mpid = mpid else { throw CodingError.keyNotFound("mpid") }
                    guard let type = type else { throw CodingError.keyNotFound("type") }
                    guard let gid = gid else { throw CodingError.keyNotFound("gid") }

                    return Self(mpid: mpid, type: type, dbo: dbo, gid: gid, name: name, state: state, apiTimestamp: apiTimestamp, gatewayTimestamp: gatewayTimestamp, eventData: eventData)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: "mpid", value: mpid)
                    try objectEncoder.encode(key: "type", value: type)
                    if let dbo = dbo {
                        try objectEncoder.encode(key: "dbo", value: dbo)
                    }
                    try objectEncoder.encode(key: "gid", value: gid)
                    if let name = name {
                        try objectEncoder.encode(key: "name", value: name)
                    }
                    if let state = state {
                        try objectEncoder.encode(key: "state", value: state)
                    }
                    if let apiTimestamp = apiTimestamp {
                        try objectEncoder.encode(key: "apiTimestamp", value: apiTimestamp)
                    }
                    if let gatewayTimestamp = gatewayTimestamp {
                        try objectEncoder.encode(key: "gatewayTimestamp", value: gatewayTimestamp)
                    }
                    if let eventData = eventData {
                        try objectEncoder.encode(key: "eventData", value: eventData)
                    }
                }
            }

            static func == (lhs: Properties, rhs: Properties) -> Bool {
                return lhs.mpid == rhs.mpid && lhs.type == rhs.type && lhs.dbo == rhs.dbo && lhs.gid == rhs.gid && lhs.name == rhs.name && lhs.state == rhs.state && lhs.apiTimestamp == rhs.apiTimestamp && lhs.gatewayTimestamp == rhs.gatewayTimestamp && lhs.eventData == rhs.eventData
            }
        }

        struct DBO: Codable, JSONCodable, Equatable {
            let id: ID
            let gid: Int
            let mpid: String
            let name: String
            let type: String
            let version: Int

            enum CodingKeys: String, CodingKey {
                case id = "_id"
                case gid, mpid, name, type, version
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var id: ID?
                    var gid: Int?
                    var mpid: String?
                    var name: String?
                    var type: String?
                    var version: Int?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "_id":
                            id = try valueDecoder.decode(ID.self)
                        case "gid":
                            gid = try valueDecoder.decode(Int.self)
                        case "mpid":
                            mpid = try valueDecoder.decode(String.self)
                        case "name":
                            name = try valueDecoder.decode(String.self)
                        case "type":
                            type = try valueDecoder.decode(String.self)
                        case "version":
                            version = try valueDecoder.decode(Int.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let id = id else { throw CodingError.keyNotFound("id") }
                    guard let gid = gid else { throw CodingError.keyNotFound("gid") }
                    guard let mpid = mpid else { throw CodingError.keyNotFound("mpid") }
                    guard let name = name else { throw CodingError.keyNotFound("name") }
                    guard let type = type else { throw CodingError.keyNotFound("type") }
                    guard let version = version else { throw CodingError.keyNotFound("version") }

                    return DBO(id: id, gid: gid, mpid: mpid, name: name, type: type, version: version)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.id.stringValue, value: id)
                    try objectEncoder.encode(key: CodingKeys.gid.stringValue, value: gid)
                    try objectEncoder.encode(key: CodingKeys.mpid.stringValue, value: mpid)
                    try objectEncoder.encode(key: CodingKeys.name.stringValue, value: name)
                    try objectEncoder.encode(key: CodingKeys.type.stringValue, value: type)
                    try objectEncoder.encode(key: CodingKeys.version.stringValue, value: version)
                }
            }
        }

        struct State: Codable, JSONCodable, Equatable {
            let apiTimestamp: String
            let attached: Bool
            let klass : String
            let errors: [String:[String]]
            let eventData: [String:Float]
            let gatewayTimestamp: String
            let gid: Int
            let id: ID
            let mpid: String
            let properties: Properties
            let type: String
            let version: Int?

            enum CodingKeys: String, CodingKey {
                case apiTimestamp, attached
                case klass = "class"
                case errors, eventData, gatewayTimestamp, gid, id, mpid, properties, type, version
            }

            static func decode<D: JSONDecoderProtocol & ~Escapable>(from decoder: inout D) throws(CodingError.Decoding) -> Self {
                return try decoder.decodeStruct { structDecoder throws(CodingError.Decoding) in
                    var apiTimestamp: String?
                    var attached: Bool?
                    var klass: String?
                    var errors: [String:[String]]?
                    var eventData: [String:Float]?
                    var gatewayTimestamp: String?
                    var gid: Int?
                    var id: ID?
                    var mpid: String?
                    var properties: Properties?
                    var type: String?
                    var version: Int?

                    try structDecoder.decodeEachKeyAndValue { key, valueDecoder throws(CodingError.Decoding) in
                        switch key {
                        case "apiTimestamp":
                            apiTimestamp = try valueDecoder.decode(String.self)
                        case "attached":
                            attached = try valueDecoder.decode(Bool.self)
                        case "class":
                            klass = try valueDecoder.decode(String.self)
                        case "errors":
                            errors = try valueDecoder.decode([String:[String]].self)
                        case "eventData":
                            eventData = try valueDecoder.decode([String:Float].self)
                        case "gatewayTimestamp":
                            gatewayTimestamp = try valueDecoder.decode(String.self)
                        case "gid":
                            gid = try valueDecoder.decode(Int.self)
                        case "id":
                            id = try valueDecoder.decode(ID.self)
                        case "mpid":
                            mpid = try valueDecoder.decode(String.self)
                        case "properties":
                            properties = try valueDecoder.decode(Properties.self)
                        case "type":
                            type = try valueDecoder.decode(String.self)
                        case "version":
                            version = try valueDecoder.decode(Int?.self)
                        default:
                            break // Skip unknown fields
                        }
                        return false
                    }

                    guard let apiTimestamp = apiTimestamp else { throw CodingError.keyNotFound("apiTimestamp") }
                    guard let attached = attached else { throw CodingError.keyNotFound("attached") }
                    guard let klass = klass else { throw CodingError.keyNotFound("klass") }
                    guard let errors = errors else { throw CodingError.keyNotFound("errors") }
                    guard let eventData = eventData else { throw CodingError.keyNotFound("eventData") }
                    guard let gatewayTimestamp = gatewayTimestamp else { throw CodingError.keyNotFound("gatewayTimestamp") }
                    guard let gid = gid else { throw CodingError.keyNotFound("gid") }
                    guard let id = id else { throw CodingError.keyNotFound("id") }
                    guard let mpid = mpid else { throw CodingError.keyNotFound("mpid") }
                    guard let properties = properties else { throw CodingError.keyNotFound("properties") }
                    guard let type = type else { throw CodingError.keyNotFound("type") }

                    return State(apiTimestamp: apiTimestamp, attached: attached, klass: klass, errors: errors, eventData: eventData, gatewayTimestamp: gatewayTimestamp, gid: gid, id: id, mpid: mpid, properties: properties, type: type, version: version)
                }
            }

            func encode(to encoder: inout JSONDirectEncoder) throws(CodingError.Encoding) {
                try encoder.encodeDictionary { objectEncoder throws(CodingError.Encoding) in
                    try objectEncoder.encode(key: CodingKeys.apiTimestamp.stringValue, value: apiTimestamp)
                    try objectEncoder.encode(key: CodingKeys.attached.stringValue, value: attached)
                    try objectEncoder.encode(key: CodingKeys.klass.stringValue, value: klass)
                    try objectEncoder.encode(key: CodingKeys.errors.stringValue, value: errors)
                    try objectEncoder.encode(key: CodingKeys.eventData.stringValue, value: eventData)
                    try objectEncoder.encode(key: CodingKeys.gatewayTimestamp.stringValue, value: gatewayTimestamp)
                    try objectEncoder.encode(key: CodingKeys.gid.stringValue, value: gid)
                    try objectEncoder.encode(key: CodingKeys.id.stringValue, value: id)
                    try objectEncoder.encode(key: CodingKeys.mpid.stringValue, value: mpid)
                    try objectEncoder.encode(key: CodingKeys.properties.stringValue, value: properties)
                    try objectEncoder.encode(key: CodingKeys.type.stringValue, value: type)
                    if let version = version {
                        try objectEncoder.encode(key: CodingKeys.version.stringValue, value: version)
                    }
                }
            }
        }
    }
}
