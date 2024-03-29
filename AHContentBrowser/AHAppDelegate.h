//
//  AHAppDelegate.h
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AHContentBrowser.h"

@interface AHAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet AHContentBrowser *contentBrowser;

@end
