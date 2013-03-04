/**
 * Copyright (c) 2012, Tom Diggle
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software
 * is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "IGDefines.h"

/* */
NSString * const IGDownloadProgressNotification = @"IGDownloadProgressNotification";

/* */
NSString * const IGMediaPlayerPlaybackLoading = @"IGMediaPlayerPlaybackLoading";
NSString * const IGMediaPlayerPlaybackStatusChangedNotification = @"IGMediaPlayerPlaybackStatusChangedNotification";
NSString * const IGMediaPlayerPlaybackFailedNotification = @"IGMediaPlayerPlaybackFailedNotification";
NSString * const IGMediaPlayerPlaybackEndedNotification = @"IGMediaPlayerPlaybackEndedNotification";
NSString * const IGMediaPlayerPlaybackBufferEmptyNotification = @"IGMediaPlayerPlaybackBufferEmptyNotification";
NSString * const IGMediaPlayerPlaybackLikelyToKeepUpNotification = @"IGMediaPlayerPlaybackLikelyToKeepUpNotification";

/* */
NSString * const IGSITMOSErrorDomain = @"com.IdleGeniusSoftware.SITMOS";

/* Fonts */
NSString * const IGFontNameRegular = @"Ubuntu";
NSString * const IGFontNameMedium = @"Ubuntu-Medium";

/* Settings */
NSString * const IGSettingCellularDataStreaming = @"IGSettingCellularDataStreaming";
NSString * const IGSettingCellularDataDownloading = @"IGSettingCellularDataDownloading";
NSString * const IGSettingEpisodesDelete = @"IGSettingEpisodesDelete"; // YES will delete episode automatically, NO will never delete episode after playback has finished.
NSString * const IGSettingUnseenBadge = @"IGSettingUnseenBadge";
NSString * const IGSettingSkippingForwardTime = @"IGSettingSkippingForwardTime";
NSString * const IGSettingSkippingBackwardTime = @"IGSettingSkippingBackwardTime";
