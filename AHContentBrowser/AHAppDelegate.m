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
    NSURL *url = [NSURL URLWithString:@"http://www.amazon.com/dp/B0050I6402/?tag=johnshorebook-20"];
    [_contentBrowser openURL:url withTitle:@"Sample Title"];
    //_contentBrowser.url = url;
}

@end
