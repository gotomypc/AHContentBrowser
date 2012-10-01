//
//  AHContentBrowser.h
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#define kAHContentBrowserLoaded @"AHContentBrowserLoaded"


@interface AHContentBrowser : WebView


@property (nonatomic) BOOL showDebugInfo;
@property (nonatomic, readonly) BOOL isShowingContent;

-(void) openURL:(NSURL*) url withTitle:(NSString*) title;

-(void) showOriginal;
-(void) showContent;

@end
