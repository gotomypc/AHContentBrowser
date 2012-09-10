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
}


-(void) awakeFromNib {
    self.wantsLayer = YES;
    self.frameLoadDelegate = self;
    
    timeTextLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 150, 30)];
    [timeTextLabel setEditable:NO];
    [timeTextLabel setBordered:NO];
    [timeTextLabel setTextColor:[NSColor redColor]];
    timeTextLabel.backgroundColor = [NSColor clearColor];
    [self addSubview:timeTextLabel];
    
    NSRect b = self.bounds;
    CGSize searchFieldSize = CGSizeMake(300, 50);
    searchField = [[NSSearchField alloc] initWithFrame:NSMakeRect((b.size.width - searchFieldSize.width)/2, 0, searchFieldSize.width, searchFieldSize.height)];
    [self addSubview:searchField];
    [searchField setAction:@selector(searchFieldChanged:)];
    searchField.target = self;
    searchField.autoresizingMask = NSViewMinXMargin;
    
    //Load in the template string
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"content" ofType:@"html"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    templateString = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
    
    // To help us debug webviews
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.url = [NSURL URLWithString:@"http://www.latimes.com/news/nation/nationnow/la-na-nn-fbi-trenton-mayor-corruption-20120910,0,7844623.story"];
}

-(IBAction)searchFieldChanged:(id)sender {
    NSString *urlString = [sender stringValue];
    self.url = [NSURL URLWithString:urlString];
}


-(void) setUrl:(NSURL *)u {
    startTime = [NSDate date];

    _url = u;
    
    // Download the data and load it into a textview
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:_url] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *res, NSData *data, NSError *e) {
        
        
        contentParser = [[AHContentParser alloc] initWithData:data];
        
        //Extract the body
        if (contentParser.foundContent) {
            
            //Load the readable  webview
            NSString *htmlString  = [templateString stringByReplacingOccurrencesOfString:@"<readableTemplate/>" withString:contentParser.contentHTML];
            NSString *path = [[NSBundle mainBundle] bundlePath];
            NSURL *baseURL = [NSURL fileURLWithPath:path];
            [[self mainFrame] loadHTMLString:htmlString baseURL:baseURL];
            
            NSTimeInterval textTime = [[NSDate date] timeIntervalSinceDate:startTime];
            timeTextLabel.stringValue = [NSString stringWithFormat:@"Time: %f", textTime];
            

        }
    }];

}

@end
