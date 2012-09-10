//
//  AHContentBrowser.h
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AHContentBrowser : WebView


@property (nonatomic) BOOL showDebugInfo;
@property (nonatomic) NSURL *url;

@end
