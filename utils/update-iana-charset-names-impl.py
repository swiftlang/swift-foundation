#!/usr/bin/env python3
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2025 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
## See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
##
##===----------------------------------------------------------------------===##

"""
This is a python script that converts an XML file containing the list of IANA
"Character Sets" to Swift source code.
This script generates minimum code and is intended to be executed by other shell
script.
"""

import re
import urllib.request as request
import xml.etree.ElementTree as ElemTree
from typing import List, Optional

REQUIRED_CHARSET_NAMES: List[str] = [
    "UTF-8",
    "US-ASCII",
    "EUC-JP",
    "ISO-8859-1",
    "Shift_JIS",
    "ISO-8859-2",
    "UTF-16",
    "windows-1251",
    "windows-1252",
    "windows-1253",
    "windows-1254",
    "windows-1250",
    "ISO-2022-JP",
    "macintosh",
    "UTF-16BE",
    "UTF-16LE",
    "UTF-32",
    "UTF-32BE",
    "UTF-32LE",
]
CHARSETS_XML_URL = "https://www.iana.org/assignments/character-sets/character-sets.xml"
CHARSETS_XML_NS = "http://www.iana.org/assignments"
SWIFT_CODE_INDENT = "    "


class IANACharsetNameRecord:
    """Representation of <record> element in 'character-sets.xml'

    The structure of <record> element is as blow:
    <record>
        <name>US-ASCII</name>
        <xref type="rfc" data="rfc2046"/>
        <value>3</value>
        <description>ANSI X3.4-1986</description>
        <alias>iso-ir-6</alias>
        <alias>ANSI_X3.4-1968</alias>
        <alias>ANSI_X3.4-1986</alias>
        <alias>ISO_646.irv:1991</alias>
        <alias>ISO646-US</alias>
        <alias>US-ASCII</alias>
        <alias>us</alias>
        <alias>IBM367</alias>
        <alias>cp367</alias>
        <alias>csASCII</alias>
        <preferred_alias>US-ASCII</preferred_alias>
    </record>
    """

    def __init__(self, recordElem: ElemTree.Element):
        self._name: str = recordElem.find('./{%s}name' % (CHARSETS_XML_NS)).text
        self._preferredMIMEName: Optional[str] = getattr(
            recordElem.find('./{%s}preferred_alias' % (CHARSETS_XML_NS)),
            'text',
            None
        )
        self._aliases: List[str] = list(map(
            lambda aliasElem: aliasElem.text,
            recordElem.findall('./{%s}alias' % (CHARSETS_XML_NS))
        ))
        self._camelCasedName = None

    @property
    def name(self) -> str:
        return self._name

    @property
    def preferredMIMEName(self) -> Optional[str]:
        return self._preferredMIMEName

    @property
    def representativeName(self) -> str:
        return self.preferredMIMEName or self.name

    @property
    def aliases(self) -> List[str]:
        return self._aliases

    @property
    def camelCasedName(self) -> str:
        if (self._camelCasedName is not None):
            return self._camelCasedName

        camelCasedName = ""
        previousWord = None
        for ii, word in enumerate(re.split(r"[^0-9A-Za-z]", self.representativeName)):
            if previousWord is None:
                camelCasedName = word.lower()
            else:
                if re.search(r"[0-9]$", previousWord) and re.search(r"^[0-9]", word):
                    camelCasedName += "_"

                if (re.fullmatch("[0-9]*[A-Z]+", word)):
                    camelCasedName += word
                else:
                    camelCasedName += word.capitalize()

            previousWord = word

        self._camelCasedName = camelCasedName
        return camelCasedName

    @property
    def swiftCodeLines(self) -> List[str]:
        def __stringLiteralOrNil(string: Optional[str]) -> str:
            if (string is None):
                return 'nil'
            return f'"{string}"'

        lines: List[str] = []
        lines.append(f"/// IANA Charset `{self.representativeName}`.")
        lines.append(f"static let {self.camelCasedName} = IANACharset(")
        lines.append(f"{SWIFT_CODE_INDENT}preferredMIMEName: {
            __stringLiteralOrNil(self.preferredMIMEName)
        },")
        lines.append(f'{SWIFT_CODE_INDENT}name: "{self.name}",')
        lines.append(f"{SWIFT_CODE_INDENT}aliases: [")
        for alias in self.aliases:
            lines.append(f"{SWIFT_CODE_INDENT * 2}\"{alias}\",")
        lines.append(f"{SWIFT_CODE_INDENT}]")
        lines.append(")")
        return lines


def generateSwiftCode() -> str:
    charsetsXMLString = request.urlopen(request.Request(CHARSETS_XML_URL)).read()
    charsetsXMLRoot = ElemTree.fromstring(charsetsXMLString)
    charsetsXMLRecordElements = charsetsXMLRoot.findall(
        "./{%s}registry/{%s}record" % (CHARSETS_XML_NS, CHARSETS_XML_NS)
    )
    result = "extension IANACharset {"
    for record in map(
        lambda recordElem: IANACharsetNameRecord(recordElem),
        charsetsXMLRecordElements
    ):
        if (record.representativeName not in REQUIRED_CHARSET_NAMES):
            continue
        result += "\n"
        result += "\n".join(map(
            lambda line: SWIFT_CODE_INDENT + line,
            record.swiftCodeLines
        ))
        result += "\n"
    result += "}\n"
    return result


if __name__ == "__main__":
    print(generateSwiftCode())
