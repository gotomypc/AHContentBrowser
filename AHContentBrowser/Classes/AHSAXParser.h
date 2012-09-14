//
//  AHSAXParser.h
//  AHContentBrowser
//
//  This is a direct port of https://github.com/fb55/node-htmlparser by Felix Böhm.
//  Many thanks to him for this very fast, simple and forgiving html parser
//
//  Created by John Wright on 9/13/12.
//  Copyright (c) 2012 John Wright. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol AHSaxParserDelegate <NSObject>

@optional

-(void) onCDATAStart;
-(void) onCDATAEnd;
-(void) onComment:(NSString*) comment;
-(void) onCommentEnd;
-(void) onOpenTagName:(NSString*)tag;
-(void) onOpenTagEnd;
-(void) onAttributeName:(NSString*)name value:(NSString*) value;
-(void) onCloseTag:(NSString*)tag;
-(void) onError;
-(void) onProcessingInstruction:(NSString*) processingInstruction elementData:(NSString*) elementData;
-(void) onReset;
-(void) onText:(NSString*) text;
-(void) onEnd;

@end


@interface AHSAXParser : NSObject

-(id) initWithDelegate:(id<AHSaxParserDelegate>)delegate;

-(void) parseChunk:(NSString*) data;
-(void) end:(NSString*) data;

@property (nonatomic) BOOL useLowerCaseTags;
@property (nonatomic) BOOL shouldParseAsXML;
@property (nonatomic) BOOL useLowerCaseAttributeNames;

@end
