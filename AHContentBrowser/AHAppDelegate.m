//
//  AHAppDelegate.m
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import "AHAppDelegate.h"

@implementation AHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _contentBrowser.showDebugInfo = YES;
    // Insert code here to initialize your application
    NSURL *url = [NSURL URLWithString:@"http://www.npr.org/blogs/itsallpolitics/2012/09/22/161599747/theres-still-time-for-romney-to-make-an-effective-case?sc=fb&cc=fp"];
    [_contentBrowser openURL:url withTitle:@"Sample Title"];
    //_contentBrowser.url = url;
}

@end
