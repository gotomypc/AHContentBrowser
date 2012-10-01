//
//  AHContentBrowser.m
//  AHContentBrowser
//
//  Created by John Wright on 9/10/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import "AHContentBrowser.h"
#import "AHContentParser.h"


@implementation AHContentBrowser{
    NSString *templateString;
    NSTextField *timeTextLabel;
    NSSearchField *searchField;
    NSDate *startTime;
    NSMutableDictionary *cache;
    NSRegularExpression *_reImgUrl;
    NSRegularExpression *_reLoadDirectly;
    NSString *_title;
    NSURL *_currentDownloadingURL;
    AHContentParser *_currentContentParser;
}


-(void) awakeFromNib {
    
    self.wantsLayer = YES;
    self.frameLoadDelegate = self;
    
    cache = [NSMutableDictionary dictionary];
    
    _reLoadDirectly = [NSRegularExpression regularExpressionWithPattern:@"http:\\/\\/(?:www\\.)?(?:amazon|facebook)\\.com" options:0 error:0];
    _reImgUrl = [NSRegularExpression regularExpressionWithPattern:@"\\.(gif|jpe?g|png|webp)$" options:0 error:0];
    //_reNoContentUrl = [NSRegularExpression regularExpressionWithPattern:@"http:////" options:0 error:0];

    
    //Load in the template string
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"content" ofType:@"html"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    templateString = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    
    // To help us debug webviews
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
    [[NSUserDefaults standardUserDefaults] synchronize];    
}


- (BOOL) isShowingContent {
    BOOL answer = [self stringByEvaluatingJavaScriptFromString:@"document.getElementById('readableTitle').innerHTML"].length != 0;
    return answer;
}

// Local resources loaded via html string do not change the browser history and hence
// the user can't navigate back to our content.html
// We accomodate that here
-(BOOL) canGoBack {
    BOOL webViewCanGoBack = [super canGoBack];
    NSString *webViewURL = self.mainFrameDocument.URL;
    if (webViewURL && !webViewCanGoBack && !self.isShowingContent) {
        return YES;
    }
    return webViewCanGoBack;
}

-(BOOL) goBack {
    if (![super canGoBack] && !self.isShowingContent && _currentContentParser.foundContent) {
        [self loadWebViewFromParser:_currentContentParser showOriginal:NO];
        return YES;
    }
    return [super goBack];
}


-(IBAction)searchFieldChanged:(id)sender {
    NSString *urlString = [sender stringValue];
    [self openURL:[NSURL URLWithString:urlString] withTitle:@""];
}


-(BOOL) shouldLoadDirectly:(NSURL*) url {
    NSString *urlString = url.absoluteString;
    if ([_reImgUrl numberOfMatchesInString:urlString options:NSCaseInsensitiveSearch range:NSMakeRange(0, urlString.length)] || [_reLoadDirectly numberOfMatchesInString:urlString options:NSCaseInsensitiveSearch range:NSMakeRange(0, urlString.length)]) {
        return YES;
    }
    return NO;
}

-(void) openURL:(NSURL*) url withTitle:(NSString*) title {
    _title = title;

    startTime = [NSDate date];
    
    // see if we have anything in cache for this url
    AHContentParser *contentParser = [cache objectForKey:url];
    if (contentParser) {
        [self loadWebViewFromParser:contentParser showOriginal:NO];
        return;
    }
    
    
    if ([self shouldLoadDirectly:url]) {
        AHContentParser *p = [[AHContentParser alloc] init];
        p.url = url;
        [self loadWebViewFromParser:p showOriginal:YES];
        return;
    }
    
    _currentDownloadingURL = url;
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:_currentDownloadingURL] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *res, NSData *data, NSError *e) {
        
        if (![res.URL.absoluteString isEqualToString:_currentDownloadingURL.absoluteString]) {
            return;
        }
        

        
        NSTimeInterval downloadTime = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog(@"Time to download: %f", downloadTime);
        AHContentParser *contentParser = [[AHContentParser alloc] initWithData:data handler:^(AHContentParser *parser) {
            parser.url = url;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self loadWebViewFromParser:parser showOriginal:NO];
            });
        }];
        [contentParser start];
        
    }];
}

-(void) sendNotificatonAboutParser:(AHContentParser*) parser {
    NSDictionary *userInfo = @{@"foundContent" : [NSNumber numberWithBool:parser.foundContent], @"url": parser.url};
    NSNotification *note = [NSNotification notificationWithName:kAHContentBrowserLoaded object:parser userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:note];

}

-(void) loadWebViewFromParser:(AHContentParser*) parser showOriginal:(BOOL) showOriginal {
    NSString *contentHTML = parser.contentHTML;
    if (contentHTML && !showOriginal) {
        
        //Load the readable  webview
        NSString *htmlString = parser.contentHTMLWithTemplate;
        if (!htmlString) {
            htmlString  = [templateString stringByReplacingOccurrencesOfString:@"<readableTemplate/>" withString:contentHTML];
            if (_title && _title.length > 0) {
                htmlString = [htmlString stringByReplacingOccurrencesOfString:@"<readableTitle/>" withString:_title];
            }
            parser.contentHTMLWithTemplate = htmlString;
        }
        
        [[self mainFrame] loadHTMLString:htmlString baseURL:parser.url];
        NSTimeInterval textTime = [[NSDate date] timeIntervalSinceDate:startTime];
        timeTextLabel.stringValue = [NSString stringWithFormat:@"Time: %f", textTime];
        
    } else if (parser.htmlString) {
        // Load the already downloaded url
        [[self mainFrame] loadHTMLString:parser.htmlString baseURL:parser.url];
    } else {
        [[self mainFrame] loadRequest:[NSURLRequest requestWithURL:parser.url]];
    }

    [cache setObject:parser forKey:parser.url];
    _currentContentParser = parser;
    [self sendNotificatonAboutParser:parser];
}


-(void) showOriginal {
    [self loadWebViewFromParser:_currentContentParser showOriginal:YES];
}

-(void) showContent {
    [self loadWebViewFromParser:_currentContentParser showOriginal:NO];
}


-(void) setShowDebugInfo:(BOOL)s {
    _showDebugInfo = s;
    
    if (_showDebugInfo) {
        NSRect b = self.bounds;
        if (!timeTextLabel) {
            timeTextLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 150, 30)];
            [timeTextLabel setEditable:NO];
            [timeTextLabel setBordered:NO];
            [timeTextLabel setTextColor:[NSColor redColor]];
            timeTextLabel.backgroundColor = [NSColor clearColor];
            CGSize searchFieldSize = CGSizeMake(300, 50);
            searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect((b.size.width - searchFieldSize.width)/2, 0, searchFieldSize.width, searchFieldSize.height)];
            [searchField setAction:@selector(searchFieldChanged:)];
            searchField.target = self;
            searchField.autoresizingMask = NSViewMinXMargin;
        }
        [self addSubview:timeTextLabel];
        [self addSubview:searchField];
    } else {
        [timeTextLabel removeFromSuperview];
        [searchField removeFromSuperview];
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    
    if ([frame isEqualTo:[self mainFrame]]) {
        NSTimeInterval downloadTime = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog(@"Time to final rendering of webview: %f", downloadTime);
        [self sendNotificatonAboutParser:_currentContentParser];
    }
}



@end
