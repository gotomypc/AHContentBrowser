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
    _contentBrowser.url = [NSURL URLWithString:@"http://dirt.mpora.com/news/friday-insert-title-randoms.html"];
}

@end
