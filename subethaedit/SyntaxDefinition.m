//
//  SyntaxDefinition.m
//  SyntaxTestBench
//
//  Created by Martin Pittenauer on Wed Mar 17 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "SyntaxDefinition.h"
#import "NSColorTCMAdditions.h"


@implementation SyntaxDefinition
/*"A Syntax Definition"*/

#pragma mark - 
#pragma mark - Initizialisation
#pragma mark - 


/*"Initiates the Syntax Definition with an XML file"*/
- (id)initWithFile:(NSString *)aPath {
    self=[super init];
    if (self) {
        // Alloc & Init
        I_defaultState = [NSMutableDictionary new];
        I_states = [NSMutableArray new];
        I_name = [@"Not named" retain];
                
        // Parse XML File
        [self parseXMLFile:aPath];
        
        // Setup stuff <-> style dictionaries
        I_stylesForToken = [NSMutableArray new];
        I_stylesForRegex = [NSMutableArray new];
        [self cacheStyles];
        [self setCombinedStateRegex];        
    }
    DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Initiated new SyntaxDefinition:%@",[self description]);
    return self;
}

- (void)dealloc {
    [I_name release];
    [I_states release];
    [I_defaultState release];
    [I_stylesForToken release];
    [I_stylesForRegex release];
    [super dealloc];
}

#pragma mark - 
#pragma mark - XML parsing
#pragma mark - 

/*"Entry point for XML parsing, branches to according node functions"*/
-(void)parseXMLFile:(NSString *)aPath {
    CFXMLTreeRef cfXMLTree;
    CFDataRef xmlData;
    if (!(aPath)) NSLog(@"ERROR: Can't parse nil syntax definition.");
    CFURLRef sourceURL = (CFURLRef)[NSURL fileURLWithPath:aPath];
    NSDictionary *errorDict;

    CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, sourceURL, &xmlData, NULL, NULL, NULL);

    cfXMLTree = CFXMLTreeCreateFromDataWithError(kCFAllocatorDefault,xmlData,sourceURL,kCFXMLParserSkipWhitespace,kCFXMLNodeCurrentVersion,(CFDictionaryRef *)&errorDict);

    if (!cfXMLTree) {
        NSLog(@"Error parsing syntax definition \"%@\":\n%@", aPath, [errorDict description]);
        CFRelease(cfXMLTree);
        return;
    }        

    
    CFXMLTreeRef    xmlTree = NULL;
    CFXMLNodeRef    xmlNode = NULL;
    int             childCount;
    int             index;

    // Get a count of the top level node’s children.
    childCount = CFTreeGetChildCount(cfXMLTree);

    // Print the data string for each top-level node.
    for (index = 0; index < childCount; index++) {
        xmlTree = CFTreeGetChildAtIndex(cfXMLTree, index);
        xmlNode = CFXMLTreeGetNode(xmlTree);
        if ((CFXMLNodeGetTypeCode(xmlNode) == kCFXMLNodeTypeElement) &&
            [@"syntax" isEqualToString:(NSString *)CFXMLNodeGetString(xmlNode)]) {
            DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Top level node: %@", (NSString *)CFXMLNodeGetString(xmlNode));
            DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Childs: %d", CFTreeGetChildCount(xmlTree));
            break;
        }
    }

    if (xmlTree && xmlNode) {
        childCount = CFTreeGetChildCount(xmlTree);
        
        for (index = 0; index < childCount; index++) {
            CFXMLTreeRef xmlSubTree = CFTreeGetChildAtIndex(xmlTree, index);
            CFXMLNodeRef xmlSubNode = CFXMLTreeGetNode(xmlSubTree);
            DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Found: %@", (NSString *)CFXMLNodeGetString(xmlSubNode));

            if ([@"head" isEqualToString:(NSString *)CFXMLNodeGetString(xmlSubNode)]) {
                [self parseHeaders:xmlSubTree];

            } else if ([@"states" isEqualToString:(NSString *)CFXMLNodeGetString(xmlSubNode)]) {
                [self parseStatesForTreeNode:xmlSubTree];

            }
        }
    }
    CFRelease(cfXMLTree);
}

/*"Parse the <head> tag"*/
- (void)parseHeaders:(CFXMLTreeRef)aTree
{
    int childCount;
    int index;

    childCount = CFTreeGetChildCount(aTree);
    for (index = 0; index < childCount; index++) {
        CFXMLTreeRef xmlTree = CFTreeGetChildAtIndex(aTree, index);
        CFXMLNodeRef xmlNode = CFXMLTreeGetNode(xmlTree);
        if (CFXMLNodeGetTypeCode(xmlNode) == kCFXMLNodeTypeElement) {
            NSString *tag     = (NSString *)CFXMLNodeGetString(xmlNode);
            // Text Content
            if ([@"name" isEqualToString:tag]) {
                if (CFTreeGetChildCount(xmlTree) == 1) { 
                    CFXMLNodeRef textNode=CFXMLTreeGetNode(CFTreeGetFirstChild(xmlTree));
                    if (CFXMLNodeGetTypeCode(textNode) == kCFXMLNodeTypeText) {
                        [self setName:(NSString *)CFXMLNodeGetString(textNode)];
                    }
                }
            // CData Content
            } else if ([@"charsintokens" isEqualToString:tag] || 
                       [@"charsdelimitingtokens" isEqualToString:tag]) {
                int childCount = CFTreeGetChildCount(xmlTree);
                int childIndex = 0;
                for (childIndex = 0; childIndex < childCount; childIndex++) {
                    CFXMLNodeRef node = CFXMLTreeGetNode(CFTreeGetChildAtIndex(xmlTree, childIndex));
                    if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeCDATASection) {
                        NSString *content = (NSString *)CFXMLNodeGetString(node);
                        NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:content];
                        if ([@"charsdelimitingtokens" isEqualToString:tag]) {
                            set = [set invertedSet];
                        }
                        [self setTokenSet:set];
                        break;
                    }
                }
            } 
        }
    }
}

/*"Parse the <states> tag"*/
- (void)parseStatesForTreeNode:(CFXMLTreeRef)aTree
{
    int childCount;
    int index;
    
    childCount = CFTreeGetChildCount(aTree);
    for (index = 0; index < childCount; index++) {
        CFXMLTreeRef xmlTree = CFTreeGetChildAtIndex(aTree, index);
        CFXMLNodeRef xmlNode = CFXMLTreeGetNode(xmlTree);
        CFXMLElementInfo eInfo = *(CFXMLElementInfo *)CFXMLNodeGetInfoPtr(xmlNode);
        NSDictionary *attributes = (NSDictionary *)eInfo.attributes;
        NSString *tag = (NSString *)CFXMLNodeGetString(xmlNode);
        DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Found: %@", tag);
        if ([@"state" isEqualToString:tag]) {
            NSMutableDictionary *aDictionary = [NSMutableDictionary dictionary];
            [I_states addObject:aDictionary];
            [aDictionary addEntriesFromDictionary:attributes]; //FIXME: Cache styles
            NSColor *aColor;
            if ((aColor = [NSColor colorForHTMLString:[attributes objectForKey:@"color"]])) 
                [aDictionary setObject:aColor forKey:@"color"];
            if ((aColor = [NSColor colorForHTMLString:[attributes objectForKey:@"background-color"]]))
                [aDictionary setObject:aColor forKey:@"background-color"];
            [self stateForTreeNode:xmlTree toDictionary:aDictionary];
        } else if ([@"default" isEqualToString:tag]) {
            [I_defaultState addEntriesFromDictionary:attributes];
            [self stateForTreeNode:xmlTree toDictionary:I_defaultState];
        }
    }
}

/*"Parse <state> and <default> tags"*/
- (void)stateForTreeNode:(CFXMLTreeRef)aTree toDictionary:(NSMutableDictionary *)aDictionary
{
    int childCount;
    int index;
        
    childCount = CFTreeGetChildCount(aTree);
    for (index = 0; index < childCount; index++) {
        CFXMLTreeRef xmlTree = CFTreeGetChildAtIndex(aTree, index);
        CFXMLNodeRef node = CFXMLTreeGetNode(xmlTree);
        NSString *tag = (NSString *)CFXMLNodeGetString(node);
        if ([@"begin" isEqualToString:tag]) {
            DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Found <begin> tag");
            CFXMLTreeRef firstTree = CFTreeGetFirstChild(xmlTree);
            CFXMLNodeRef firstNode = CFXMLTreeGetNode(firstTree);
            CFXMLTreeRef secondTree = CFTreeGetFirstChild(firstTree);
            CFXMLNodeRef secondNode = CFXMLTreeGetNode(secondTree);
            NSString *innerTag = (NSString *)CFXMLNodeGetString(firstNode);
            NSString *innerContent = (NSString *)CFXMLNodeGetString(secondNode);
            if ([innerTag isEqualTo:@"regex"]) {
                DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"<begin> tag is RegEx");
                [aDictionary setObject:innerContent forKey:@"BeginsWithRegexString"];
            } else if ([innerTag isEqualTo:@"string"]) {
                DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"<begin> tag is PlainString");
                [aDictionary setObject:innerContent forKey:@"BeginsWithPlainString"];
            }
        // FIXME: Case insensitivity, strings!
        } else if ([@"end" isEqualToString:tag]) {
            DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Found <end> tag");
            CFXMLTreeRef firstTree = CFTreeGetFirstChild(xmlTree);
            CFXMLNodeRef firstNode = CFXMLTreeGetNode(firstTree);
            CFXMLTreeRef secondTree = CFTreeGetFirstChild(firstTree);
            CFXMLNodeRef secondNode = CFXMLTreeGetNode(secondTree);
            NSString *innerTag = (NSString *)CFXMLNodeGetString(firstNode);
            NSString *innerContent = (NSString *)CFXMLNodeGetString(secondNode);
            
            if ([innerTag isEqualTo:@"regex"]) {
                DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"<end> tag is RegEx");
                [aDictionary setObject:innerContent forKey:@"EndsWithRegexString"];
                
                OGRegularExpression *endRegex;
                if ([OGRegularExpression isValidExpressionString:innerContent]) {
                    //if (endRegex = [[[OGRegularExpression alloc] initWithString:innerContent options:OgreFindLongestOption|OgreFindNotEmptyOption] autorelease])
                    if ((endRegex = [[[OGRegularExpression alloc] initWithString:innerContent options:OgreFindNotEmptyOption] autorelease]))
                        [aDictionary setObject:endRegex forKey:@"EndsWithRegex"];
                } else NSLog(@"ERROR: %@ is not a valid Regex.", innerContent);
                
            } else if ([innerTag isEqualTo:@"string"]) {
                DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"<end> tag is PlainString");
                [aDictionary setObject:innerContent forKey:@"EndsWithPlainString"];
            }
        } else if ([@"keywords" isEqualToString:tag]) {
            NSMutableDictionary *groups;

            if (!(groups = [aDictionary objectForKey:@"KeywordGroups"])) {
                [aDictionary setObject:[NSMutableDictionary dictionary] forKey:@"KeywordGroups"];
                groups = [aDictionary objectForKey:@"KeywordGroups"];
            }
            
            CFXMLElementInfo eInfo = *(CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
            NSDictionary *attributes = (NSDictionary *)eInfo.attributes;

            NSString *keywordName = [attributes objectForKey:@"id"];
            [groups setObject:[NSMutableDictionary dictionary] forKey:keywordName];

            NSMutableDictionary *keywordGroup = [groups objectForKey:keywordName];
            [keywordGroup addEntriesFromDictionary:attributes];
            
            [self addKeywordsForTreeNode:xmlTree toDictionary:keywordGroup];
        }
    }
}

/*"Parse <string> and <regex> tags for keyword groups"*/
- (void)addKeywordsForTreeNode:(CFXMLTreeRef)aTree toDictionary:(NSMutableDictionary *)aDictionary
{
    int childCount;
    int index;
    
    childCount = CFTreeGetChildCount(aTree);
    for (index = 0; index < childCount; index++) {
        CFXMLTreeRef xmlTree = CFTreeGetChildAtIndex(aTree, index);
        CFXMLNodeRef node = CFXMLTreeGetNode(xmlTree);
        NSString *tag = (NSString *)CFXMLNodeGetString(node);
        NSString *content = (NSString *)CFXMLNodeGetString(CFXMLTreeGetNode(CFTreeGetFirstChild(xmlTree)));
        if ([@"regex" isEqualToString:tag]) {
            NSMutableSet *regexs;
            if (!(regexs = [aDictionary objectForKey:@"RegularExpressions"])) {
                [aDictionary setObject:[NSMutableSet set] forKey:@"RegularExpressions"];
                regexs = [aDictionary objectForKey:@"RegularExpressions"];
            }
            [regexs addObject:content];
        } else if ([@"string" isEqualToString:tag]) {
            NSMutableSet *plainStrings;
            if (!(plainStrings = [aDictionary objectForKey:@"PlainStrings"])) {
                [aDictionary setObject:[NSMutableSet set] forKey:@"PlainStrings"];
                plainStrings = [aDictionary objectForKey:@"PlainStrings"];
            }
            [plainStrings addObject:content];
        }
    }
}

#pragma mark - 
#pragma mark - Caching and precalculating
#pragma mark - 

/*"calls addStylesForKeywordGroups: for defaultState and states"*/
-(void)cacheStyles
{
    NSMutableDictionary *aDictionary;
    if ((aDictionary = [I_defaultState objectForKey:@"KeywordGroups"])) {
        [self addStylesForKeywordGroups:aDictionary];
    } else {
        [I_stylesForToken addObject:[NSDictionary dictionary]];
        [I_stylesForRegex addObject:[NSDictionary dictionary]];
    }
    
    NSEnumerator *statesEnumerator = [I_states objectEnumerator];
    while ((aDictionary = [statesEnumerator nextObject])) {
        if ((aDictionary = [aDictionary objectForKey:@"KeywordGroups"])) {
            [self addStylesForKeywordGroups:aDictionary];
        } else {
            [I_stylesForToken addObject:[NSDictionary dictionary]];
            [I_stylesForRegex addObject:[NSDictionary dictionary]];
        }
    }
    
    DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Finished caching plainstrings:%@",[I_stylesForToken description]);
    DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Finished caching regular expressions:%@",[I_stylesForRegex description]);

}

/*"Creates dictionaries which match styles (color, font, etc.) to plainstrings or regexs"*/
-(void)addStylesForKeywordGroups:(NSDictionary *)aDictionary
{
    NSEnumerator *groupEnumerator = [aDictionary objectEnumerator];
    NSDictionary *keywordGroup;
    
    NSMutableDictionary *newPlainDictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary *newRegExDictionary = [NSMutableDictionary dictionary];
    [I_stylesForToken addObject:newPlainDictionary];
    [I_stylesForRegex addObject:newRegExDictionary];

    while ((keywordGroup = [groupEnumerator nextObject])) {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        NSColor *aColor;
        NSString *aString;
        if ((aColor = [NSColor colorForHTMLString:[keywordGroup objectForKey:@"color"]]))
            [attributes setObject:aColor forKey:@"color"];
        if ((aColor = [NSColor colorForHTMLString:[keywordGroup objectForKey:@"background-color"]]))
            [attributes setObject:aColor forKey:@"background-color"];
        if ((aString = [keywordGroup objectForKey:@"font-style"]))      
            [attributes setObject:aString forKey:@"font-style"];
        if ((aString = [keywordGroup objectForKey:@"font-weight"]))     
            [attributes setObject:aString forKey:@"font-weight"];
        if ((aString = [keywordGroup objectForKey:@"casesensitive"]))        
            [attributes setObject:aString forKey:@"casesensitive"];
        
        // First do the plainstring stuff
        
        NSDictionary *keywords;
        if ((keywords = [keywordGroup objectForKey:@"PlainStrings"])) {
            NSEnumerator *keywordEnumerator = [keywords objectEnumerator];
            //NSMutableDictionary *newDictionary;
            //newDictionary = [NSMutableDictionary dictionary];
            //[I_stylesForToken addObject:newDictionary];
            NSString *keyword;
            while ((keyword = [keywordEnumerator nextObject])) {
                [newPlainDictionary setObject:attributes forKey:keyword];
            }
        }
        // Then do the regex stuff
        
        if ((keywords = [keywordGroup objectForKey:@"RegularExpressions"])) {
            NSEnumerator *keywordEnumerator = [keywords objectEnumerator];
            //NSMutableDictionary *newDictionary;
            //newDictionary = [NSMutableDictionary dictionary];
            //[I_stylesForRegex addObject:newDictionary];
            NSString *keyword;
            NSString *aString;
            while ((keyword = [keywordEnumerator nextObject])) {
                OGRegularExpression *regex;
                //unsigned regexOptions = OgreFindLongestOption|OgreFindNotEmptyOption;
                unsigned regexOptions = OgreFindNotEmptyOption;
                if ((aString = [attributes objectForKey:@"casesensitive"])) {       
                    if (([aString isEqualTo:@"no"])) {
                        regexOptions = regexOptions|OgreIgnoreCaseOption;
                    }
                }
                if ([OGRegularExpression isValidExpressionString:keyword]) {
                    if ((regex = [[[OGRegularExpression alloc] initWithString:keyword options:regexOptions] autorelease]))
                        [newRegExDictionary setObject:attributes forKey:regex];
                } else {
                    NSLog(@"ERROR: %@ in \"%@\" is not a valid regular expression", keyword, [attributes objectForKey:@"id"]);
                }
            }
        }
    }
}

#pragma mark - 
#pragma mark - Accessors
#pragma mark - 

- (NSString *)description {
    return [NSString stringWithFormat:@"SyntaxDefinition, Name:%@ , TokenSet:%@, States: %@, DefaultState: %@", [self name], [self tokenSet], [I_states description], [I_defaultState description]];
}

- (NSString *)name
{
    return I_name;
}

- (void)setName:(NSString *)aString
{
    [I_name autorelease];
     I_name = [aString copy];
}

- (NSMutableArray *)states
{
    return I_states;
}

- (NSCharacterSet *)tokenSet
{
    return I_tokenSet;
}

- (NSCharacterSet *)invertedTokenSet
{
    return I_invertedTokenSet;
}

- (void)setTokenSet:(NSCharacterSet *)aCharacterSet
{
    [I_tokenSet autorelease];
     I_tokenSet = [aCharacterSet copy];
     I_invertedTokenSet = [[aCharacterSet invertedSet] copy];
}

- (NSDictionary *)styleForToken:(NSString *)aToken inState:(int)aState 
{
    NSDictionary *aStyle;
    if ((aStyle = [[I_stylesForToken objectAtIndex:aState] objectForKey:aToken])) return aStyle;
    // FIXME: Handle caseinsensitive Tokens with CFDictionary
    else return nil;
}

- (NSDictionary *)regularExpressionsInState:(int)aState
{
    NSDictionary *aRegexDictionary;
    if ((aRegexDictionary = [I_stylesForRegex objectAtIndex:aState])) return aRegexDictionary;
    else return nil;
}

- (void)setCombinedStateRegex 
{
    NSMutableString *combinedString = [NSMutableString string];
    NSEnumerator *statesEnumerator = [I_states objectEnumerator];
    NSMutableDictionary *aDictionary;
    while ((aDictionary = [statesEnumerator nextObject])) {
        NSString *beginString;
        if ((beginString = [aDictionary objectForKey:@"BeginsWithRegexString"])) {
            DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Found regex string state start:%@",beginString);
        } else if ((beginString = [aDictionary objectForKey:@"BeginsWithPlainString"])) {
            DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"Found plain string state start:%@",beginString);
        } else {
            DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"ERROR: State without begin:%@",[aDictionary description]);
        }
        if (beginString) {
            [combinedString appendString:[NSString stringWithFormat:@"(%@)|",beginString]];
        }
    }
    int combinedStringLength = [combinedString length];
    if (combinedStringLength>1) {
        [combinedString deleteCharactersInRange:NSMakeRange(combinedStringLength-1,1)];      
        [I_combinedStateRegex autorelease];
        if ([OGRegularExpression isValidExpressionString:combinedString]) {
            //I_combinedStateRegex = [[OGRegularExpression alloc] initWithString:combinedString options:OgreFindLongestOption|OgreFindNotEmptyOption|OgreCaptureGroupOption];
            I_combinedStateRegex = [[OGRegularExpression alloc] initWithString:combinedString options:OgreFindNotEmptyOption|OgreCaptureGroupOption];
        } else {
            NSLog(@"ERROR: %@ (begins of all states) is not a valid regular expression", combinedString);
        }
    }
    DEBUGLOG(@"SyntaxHighlighterDomain", AllLogLevel, @"CombinedStateRegex:%@",[self combinedStateRegex]);
}

- (OGRegularExpression *)combinedStateRegex
{
    return I_combinedStateRegex;
}


@end
