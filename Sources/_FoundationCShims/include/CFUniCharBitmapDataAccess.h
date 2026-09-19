/*
    CFUniCharBitmapDataAccess.h
    Copyright (c) 2026, Apple Inc. and the Swift project authors. All rights reserved.

    This header relies on CFUniCharBitmapData.inc.h and CFUniCharBitmapData.h
    being included before it.
*/

#ifndef _cfunichar_bitmap_data_access_h
#define _cfunichar_bitmap_data_access_h

static inline __CFUniCharBitmapData const *getCFUniCharBitmapDataArray(void) {
    return __CFUniCharBitmapDataArray;
}

#endif /* _cfunichar_bitmap_data_access_h */
