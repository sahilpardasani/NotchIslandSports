// Copyright (c) 2025 Jonas van den Berg
// This file is licensed under the BSD 3-Clause License.

#include "private/MediaRemote.h"
#include <limits.h>

#import <Foundation/Foundation.h>

#import "MediaRemoteAdapter.h"
#import "adapter/env.h"
#import "adapter/get.h"
#import "adapter/globals.h"
#import "adapter/now_playing.h"
#import "utility/helpers.h"

void adapter_seek(long position) {

    if (position < 0) {
        failf(@"Negative values are not allowed: %ld", position);
    }

    // NotchIslandSports: validate the intended source immediately before this
    // global private API call. A tiny check-to-dispatch race remains.
    NSDictionary *expected = [[NSProcessInfo processInfo] environment];
    NSString *bundle = expected[@"NOTCH_EXPECTED_MEDIA_BUNDLE"];
    NSString *title = expected[@"NOTCH_EXPECTED_MEDIA_TITLE"];
    if (bundle == nil || title == nil || title.length == 0) {
        failf(@"Seeking requires an identified player and track");
    }
    NSDictionary *current = internal_get(NO);
    if (![current[@"bundleIdentifier"] isEqualToString:bundle] ||
        ![current[@"title"] isEqualToString:title]) {
        failf(@"The current media player changed; seek cancelled");
    }
    if (g_mediaRemote.setElapsedTime == NULL) { failf(@"Seeking is unavailable"); }
    g_mediaRemote.setElapsedTime(position / 1000000.0);

    waitForCommandCompletion();
}

static inline long seek_0_position() {
    return getEnvFuncParamLongSafe(@"adapter_seek", 0, @"position");
}

void adapter_seek_env() { adapter_seek(seek_0_position()); }

