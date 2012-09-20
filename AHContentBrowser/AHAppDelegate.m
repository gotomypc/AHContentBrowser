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
    _contentBrowser.url = [NSURL URLWithString:@"http://www.huffingtonpost.com/jeremiah-goulka/mitt-romney-47-percent_b_1896569.html"];
}

@end
