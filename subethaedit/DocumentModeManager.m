//
//  DocumentModeManager.m
//  SubEthaEdit
//
//  Created by Dominik Wagner on Mon Mar 22 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "DocumentModeManager.h"

#define MODEPATHCOMPONENT @"Application Support/SubEthaEdit/Modes/"

@interface DocumentModeManager (DocumentModeManagerPrivateAdditions)
- (void)TCM_findModes;
- (void)setupMenu:(NSMenu *)aMenu action:(SEL)aSelector;
- (void)setupPopUp:(DocumentModePopUpButton *)aPopUp selectedMode:(DocumentMode *)aMode;
@end

@implementation DocumentModePopUpButton

/* Replace the cell, sign up for notifications.
*/
- (void)awakeFromNib {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentModeListChanged:) name:@"DocumentModeListChanged" object:nil];
    [[DocumentModeManager sharedInstance] setupPopUp:self selectedMode:[[DocumentModeManager sharedInstance] baseMode]];
}

- (DocumentMode *)selectedMode {
    DocumentModeManager *manager=[DocumentModeManager sharedInstance];
    return [manager documentModeForIdentifier:[manager documentModeIdentifierForTag:[[self selectedItem] tag]]];
}

- (void)setSelectedMode:(DocumentMode *)aMode {
    int tag=[[DocumentModeManager sharedInstance] tagForDocumentModeIdentifier:[[aMode bundle] bundleIdentifier]];
    [self selectItemAtIndex:[[self menu] indexOfItemWithTag:tag]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

/* Update contents based on encodings list customization
*/
- (void)documentModeListChanged:(NSNotification *)notification {
    [[DocumentModeManager sharedInstance] setupPopUp:self selectedMode:[self selectedMode]];
}

@end


@implementation DocumentModeMenu
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)documentModeListChanged:(NSNotification *)notification {
    //int tag = [[self selectedItem] tag];
    //if (tag != 0 && tag != NoStringEncoding) defaultEncoding = tag;
    //[[EncodingManager sharedInstance] setupPopUp:self selectedEncoding:defaultEncoding withDefaultEntry:hasDefaultEntry lossyEncodings:[NSArray array]];
    [[DocumentModeManager sharedInstance] setupMenu:self action:I_action];
}

- (void)configureWithAction:(SEL)aSelector {
    I_action = aSelector;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentModeListChanged:) name:@"DocumentModeListChanged" object:nil];
    [[DocumentModeManager sharedInstance] setupMenu:self action:I_action];
}
@end

@implementation DocumentModeManager

+ (DocumentModeManager *)sharedInstance {
    static DocumentModeManager *sharedInstance=nil;
    if (!sharedInstance) {
        sharedInstance = [self new];
    }
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        I_modeBundles=[NSMutableDictionary new];
        I_documentModesByIdentifier =[NSMutableDictionary new];
		I_modeIdentifiersByExtension=[NSMutableDictionary new];
		I_modeIdentifiersTagArray   =[NSMutableArray new];
		[I_modeIdentifiersTagArray addObject:@"-"];
		[I_modeIdentifiersTagArray addObject:BASEMODEIDENTIFIER];
        [self TCM_findModes];
    }
    return self;
}

- (void)dealloc {
    [I_modeBundles release];
    [I_documentModesByIdentifier release];
	[I_modeIdentifiersByExtension release];
    [super dealloc];
}

- (void)TCM_findModes {
    NSString *file;
    NSString *path;
        
    NSMutableArray *allPaths = [NSMutableArray array];
    NSArray *allDomainsPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
    NSEnumerator *enumerator = [allDomainsPaths objectEnumerator];
    while ((path = [enumerator nextObject])) {
        [allPaths addObject:[path stringByAppendingPathComponent:MODEPATHCOMPONENT]];
    }
    
    [allPaths addObject:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Modes/"]];
    
    enumerator = [allPaths reverseObjectEnumerator];
    while ((path = [enumerator nextObject])) {
        NSEnumerator *dirEnumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
        while ((file = [dirEnumerator nextObject])) {
			//NSLog(@"%@",file);
            if ([[file pathExtension] isEqualToString:@"mode"]) {
                NSBundle *bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]];
                if (bundle) {
					NSEnumerator *extensions = [[[bundle infoDictionary] objectForKey:@"TCMModeExtensions"] objectEnumerator];
					NSString *extension = nil;
					while ((extension = [extensions nextObject])) {
						[I_modeIdentifiersByExtension setObject:[bundle bundleIdentifier] forKey:extension];
					}
                    [I_modeBundles setObject:bundle forKey:[bundle bundleIdentifier]];
                    if (![I_modeIdentifiersTagArray containsObject:[bundle bundleIdentifier]]) {
                        [I_modeIdentifiersTagArray addObject:[bundle bundleIdentifier]];
                    }
                }
            }
        }
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"DocumentModeManager, FoundModeBundles:%@",[I_modeBundles description]];
}

- (DocumentMode *)documentModeForIdentifier:(NSString *)anIdentifier {
	NSBundle *bundle=[I_modeBundles objectForKey:anIdentifier];
	if (bundle) {
        DocumentMode *mode=[I_documentModesByIdentifier objectForKey:anIdentifier];
        if (!mode) {
            mode = [[[DocumentMode alloc] initWithBundle:bundle] autorelease];
            if (mode)
                [I_documentModesByIdentifier setObject:mode forKey:anIdentifier];
        }
        return mode;
	} else {
        return nil;
    }
}

- (DocumentMode *)baseMode {
    return [self documentModeForIdentifier:BASEMODEIDENTIFIER];
}

- (DocumentMode *)documentModeForExtension:(NSString *)anExtension {
    NSString *identifier=[I_modeIdentifiersByExtension objectForKey:anExtension];
    if (identifier) {
        return [self documentModeForIdentifier:identifier];
	} else {
        return [self baseMode];
	}
}


/*"Returns an NSDictionary with Key=Identifier, Value=ModeName"*/
- (NSDictionary *)availableModes {
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSEnumerator *modeIdentifiers=[I_modeBundles keyEnumerator];
    NSString *identifier = nil;
    while ((identifier=[modeIdentifiers nextObject])) {
        [result setObject:[[[I_modeBundles objectForKey:identifier] localizedInfoDictionary] objectForKey:@"CFBundleName"] 
                   forKey:identifier];
    }
    return result;
}

- (NSString *)documentModeIdentifierForTag:(int)aTag {
    if (aTag>0 && aTag<[I_modeIdentifiersTagArray count]) {
        return [I_modeIdentifiersTagArray objectAtIndex:aTag];
    } else {
        return nil;
    }
}

- (int)tagForDocumentModeIdentifier:(NSString *)anIdentifier {
    return [I_modeIdentifiersTagArray indexOfObject:anIdentifier];
}


- (void)setupMenu:(NSMenu *)aMenu action:(SEL)aSelector {

    // Remove all menu items
    int count = [aMenu numberOfItems];
    while (count) {
        [aMenu removeItemAtIndex:count - 1];
        count = [aMenu numberOfItems];
    }
    
    // Add modes
    DocumentMode *baseMode=[self baseMode];
    
    NSMutableArray *menuEntries=[NSMutableArray array];
    NSEnumerator *modeIdentifiers=[I_modeBundles keyEnumerator];
    NSString *identifier = nil;
    while ((identifier=[modeIdentifiers nextObject])) {
        if (![identifier isEqualToString:BASEMODEIDENTIFIER]) {
            [menuEntries 
                addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:identifier,@"Identifier",[[[I_modeBundles objectForKey:identifier] localizedInfoDictionary] objectForKey:@"CFBundleName"],@"Name",nil]];
        }
    }

    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[[[baseMode bundle] localizedInfoDictionary] objectForKey:@"CFBundleName"]
                                                      action:aSelector
                                               keyEquivalent:@""];
    [menuItem setTag:[self tagForDocumentModeIdentifier:BASEMODEIDENTIFIER]];
    [aMenu addItem:menuItem];
    [menuItem release];

    count=[menuEntries count];
    if (count > 0) {
        [aMenu addItem:[NSMenuItem separatorItem]];
        
        // sort
        NSArray *sortedEntries=[menuEntries sortedArrayUsingDescriptors:
                        [NSArray arrayWithObjects:
                            [[[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES] autorelease],
                            [[[NSSortDescriptor alloc] initWithKey:@"Identifier" ascending:YES] autorelease],nil]];
        
        int index=0;
        for (index=0;index<count;index++) {
            NSDictionary *entry=[sortedEntries objectAtIndex:index];
            NSMenuItem *menuItem =[[NSMenuItem alloc] initWithTitle:[entry objectForKey:@"Name"]
                                                             action:aSelector
                                                      keyEquivalent:@""];
            [menuItem setTag:[self tagForDocumentModeIdentifier:[entry objectForKey:@"Identifier"]]];
            [aMenu addItem:menuItem];
            [menuItem release];
        }
    }
}

- (void)setupPopUp:(DocumentModePopUpButton *)aPopUp selectedMode:(DocumentMode *)aMode {
    [aPopUp removeAllItems];
    NSMenu *tempMenu=[[NSMenu new] autorelease];
    [self setupMenu:tempMenu action:@selector(none:)];
    NSEnumerator *menuItems=[[tempMenu itemArray] objectEnumerator];
    NSMenuItem *item=nil;
    while ((item=[menuItems nextObject])) {
        if (![item isSeparatorItem]) {
            [aPopUp addItemWithTitle:[item title]];
            [[aPopUp lastItem] setTag:[item tag]];
            [[aPopUp lastItem] setEnabled:YES];
        }
    }
    [aPopUp setSelectedMode:aMode];
}

@end
