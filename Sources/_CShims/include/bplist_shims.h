/*
	bplist.h
	Copyright (c) 2023, Apple Inc. and the Swift project authors. All rights reserved.
*/

#ifndef _bplist_h
#define _bplist_h

typedef struct {
    uint8_t    _unused[5];
    uint8_t     _sortVersion;
    uint8_t    _offsetIntSize;
    uint8_t    _objectRefSize;
    uint64_t    _numObjects;
    uint64_t    _topObject;
    uint64_t    _offsetTableOffset;
} BPlistTrailer;

#endif /* _bplist_h */
