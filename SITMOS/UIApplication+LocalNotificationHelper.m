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

#import "UIApplication+LocalNotificationHelper.h"

@implementation UIApplication (LocalNotificationHelper)

+ (void)scheduleLocalNotificationWithParameters:(NSDictionary *)parameters
{
    NSParameterAssert(parameters != nil);
    
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    [localNotification setFireDate:[parameters valueForKey:@"fireDate"]];
    [localNotification setTimeZone:[parameters valueForKey:@"timeZone"]];
    [localNotification setAlertAction:[parameters valueForKey:@"alertAction"]];
    [localNotification setAlertBody:[parameters valueForKey:@"alertBody"]];
    [localNotification setSoundName:[parameters valueForKey:@"soundName"]];
    [[self sharedApplication] scheduleLocalNotification:localNotification];
}

@end
