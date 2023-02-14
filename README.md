# Foundation


The Foundation framework defines a base layer of functionality that is required for almost all applications. It provides primitive classes and introduces several paradigms that define functionality not provided by either the Objective-C runtime and language or Swift standard library and language.

It is designed with these goals in mind:

* Provide a small set of basic utility classes.
* Make software development easier by introducing consistent conventions.
* Support internationalization and localization, to make software accessible to users around the world.
* Provide a level of OS independence, to enhance portability.

There is more information on the Foundation framework [here](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/ObjC_classic/).

This project, provides an implementation of the Foundation API for platforms where there is no Objective-C runtime. On macOS, iOS, and other Apple platforms, apps should use the Foundation that comes with the operating system. Our goal is for the API in this project to match the OS-provided Foundation and abstract away the exact underlying platform as much as possible.
