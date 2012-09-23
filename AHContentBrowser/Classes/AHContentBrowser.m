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
    AHContentParser *contentParser;
    NSRegularExpression *_reImgUrl;
    NSString *_title;
}


-(void) awakeFromNib {
    self.wantsLayer = YES;
    self.frameLoadDelegate = self;
    
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

-(IBAction)searchFieldChanged:(id)sender {
    NSString *urlString = [sender stringValue];
    self.url = [NSURL URLWithString:urlString];
}


-(BOOL) shouldLoadDirectly:(NSURL*) url {
    NSString *urlString = url.absoluteString;
    if ([_reImgUrl numberOfMatchesInString:urlString options:NSCaseInsensitiveSearch range:NSMakeRange(0, urlString.length)]) {
        return YES;
    }
    return NO;
}

-(void) openURL:(NSURL*) url withTitle:(NSString*) title {
    _title = title;
    self.url = url;
}

-(void) setUrl:(NSURL *)u {
    startTime = [NSDate date];

    _url = u;
    
    if ([self shouldLoadDirectly:u]) {
        [[self mainFrame] loadRequest:[NSURLRequest requestWithURL:u]];
        return;
    }
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:_url] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *res, NSData *data, NSError *e) {
        
        if (![res.URL.absoluteString isEqualToString:self.url.absoluteString]) {
            return;
        }
        
        NSTimeInterval downloadTime = [[NSDate date] timeIntervalSinceDate:startTime];
        NSLog(@"Time to download: %f", downloadTime);
        contentParser = [[AHContentParser alloc] initWithData:data handler:^(AHContentParser *parser) {
            NSString *contentHTML = parser.contentHTML;
            if (contentHTML) {
                //Load the readable  webview
                NSString *htmlString;
                htmlString  = [templateString stringByReplacingOccurrencesOfString:@"<readableTemplate/>" withString:contentHTML];
                if (_title && _title.length > 0) {
                    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"<readableTitle/>" withString:_title];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [[self mainFrame] loadHTMLString:htmlString baseURL:_url];
                    NSTimeInterval textTime = [[NSDate date] timeIntervalSinceDate:startTime];
                    timeTextLabel.stringValue = [NSString stringWithFormat:@"Time: %f", textTime];
                });
                
                
            } else if (contentParser.htmlString) {
                // Load the already downloaded url
                [[self mainFrame] loadHTMLString:contentParser.htmlString baseURL:_url];
            } else {
                [[self mainFrame] loadRequest:[NSURLRequest requestWithURL:_url]];
            }
        }];
        [contentParser start];
        
    }];
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

@end
