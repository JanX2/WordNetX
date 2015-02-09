//
//  AppController.m
//  WordNetX
//
//  Created by William Taysom on Mon Aug 25 2003.
//

#import "AppController.h"
#import "WordNetManager.h"

#define DEB(_x) NSLog(@"%@", _x)

#define LINE_BOTTOM_MARGIN_FACTOR 1.06
#define LINE_BOTTOM_MARGIN 8
#define VERTICAL_MARGIN_FACTOR 0.92

NSString *verbsString = @"VERBS";

@implementation NSTableView (NSTableViewExtentionForWordNetX)
- (NSTableColumn *)mainColumn
{
    return [[self tableColumns] objectAtIndex:0];
}
@end

@implementation NSMutableArray (NSMutableArrayExtentionForWordNetX)
- (void)setObject:(id)anObject forIndex:(NSInteger)index
{
    if (index < [self count])
        [self replaceObjectAtIndex:index withObject:anObject];
    while (index > [self count])
        [self addObject:[NSNull null]];
    [self addObject:anObject];
}
@end

@implementation AppController

//*** Private Methods

- (void)setTheWord:(NSString *)w
{
    [w retain];
    [theWord release];
    theWord = w;
    theWordChanged = YES;
}

- (void)setTheSynset:(NSNumber *)s
{
    [s retain];
    [theSynset release];
    theSynset = s;
    theSynsetChanged = YES;
}

- (void)setSenses:(NSArray *)s
{
    [s retain];
    [senses release];
    senses = s;
}

- (void)setGuessesForWord:(NSString *)word
{
	NSRange wordRange = NSMakeRange(0, word.length);
    NSArray *g = [spellChecker guessesForWordRange:wordRange
										  inString:word
										  language:@"en"
							inSpellDocumentWithTag:0];
    [g retain];
    [guesses release];
    guesses = g;
}

- (void)setCurrentEntry
{   
    NSArray *entry = [NSArray arrayWithObjects:theWord, theSynset, nil];
    if (timeTraveling)
        return;
    if (currentEntry)
        [backStack addObject:currentEntry];

    [entry retain];
    [currentEntry release];
    currentEntry = entry;
}

- (void)setSensesTableColumnsWidth
{
    NSInteger i;
    CGFloat testHeight, height;
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    NSCell *cell = [[NSCell alloc] init];
    
    programResizing = YES;
    
    height = 16.0;
    for (i = 0; i < [senses count]; ++i) {
        [cell setAttributedStringValue:[[NSAttributedString alloc]
            initWithString:[wordNet glossForSynset:[senses objectAtIndex:i]]
            attributes:attrs]];
        testHeight = [cell cellSizeForBounds:NSMakeRect(0, 0,
            [[sensesTable mainColumn] width] * VERTICAL_MARGIN_FACTOR, 50000)].height;
        
        if (testHeight > height)
            height = testHeight;
    }
    [sensesTable setRowHeight:height * LINE_BOTTOM_MARGIN_FACTOR + LINE_BOTTOM_MARGIN];
    
    programResizing = NO;
}

- (void)updateGuesses {
    if ((misspelling = ([senses count] == 0))) {
	[self setGuessesForWord:theWord];
        [[[sensesTable mainColumn] headerCell] setStringValue:@"Not Found"];
        [[[relationsView mainColumn] headerCell] setStringValue:@"Guesses"]; 
    } else {
        [[[sensesTable mainColumn] headerCell] setStringValue:@"Senses"];
        [[[relationsView mainColumn] headerCell] setStringValue:@"Relations"]; 
    }
}

- (void)updateRelations
{        
    NSInteger totalVisibleRelations =
        [self outlineView:relationsView numberOfChildrenOfItem:nil];
    NSString *relation;
    NSInteger i;
    
    [relationsView reloadData];
    [relationsView deselectAll:nil];
    for (i = 0; i < totalVisibleRelations; ++i) {
        relation = [self outlineView:relationsView child:i ofItem:nil];
        
        if ([expandedRelations containsObject:relation])
            [relationsView expandItem:relation];
        else
            [relationsView collapseItem:relation];
    }

}

- (void)updateHierarchy
{
    NSArray *ancestry = [wordNet ancestryForSynset:theSynset];
    NSInteger i, j = 0;
    
    if ([wordNet posForSynset:theSynset] == verb)
        [hierarchyBrowser selectRow:[[hierarchyData objectAtIndex:0] count] 
            inColumn:j++];
    for (i = [ancestry count] - 1; i >= 0; --i, ++j)
        [hierarchyBrowser
            selectRow:[[hierarchyData objectAtIndex:j] indexOfObject:
                [ancestry objectAtIndex:i]]
            inColumn:j];
}

- (void)updateButtons
{
    BOOL enabled;
    if ([backStack count] > 0)
        enabled = YES;
    else
        enabled = NO;        
    [backButton setEnabled:enabled];
    
    if ([forwardStack count] > 0)
        enabled = YES;
    else
        enabled = NO;
    [forwardButton setEnabled:enabled];
}

- (void)updateUI
{   
    [self updateGuesses];
    
    if (theWordChanged) {
        [searchField setStringValue:theWord];
        [self setSenses:[wordNet synsetsForInflectedWord:theWord]];
        [self updateGuesses];
        [self setSensesTableColumnsWidth];
        [sensesTable reloadData];
        [sensesTable deselectAll:nil];
        if (!theSynset && [senses count])
            [self setTheSynset:[senses objectAtIndex:0]];
        theWordChanged = NO;
    }
    if (theSynsetChanged) {
        if (theSynset)
            [sensesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:[senses indexOfObject:theSynset]]
                byExtendingSelection:NO];
        theSynsetChanged = NO;
    }
    [self setCurrentEntry];
    
    [self updateRelations];
    
    if ([wordNet posForSynset:theSynset] == adj
            || [wordNet posForSynset:theSynset] == adv)
        [hierarchyBrowser loadColumnZero];
    else
        [self updateHierarchy];
        
    [self updateButtons];
}

- (void)updateFromHistory:(NSArray *)entry
{    
    timeTraveling = YES;
    [self setTheWord:[entry objectAtIndex: 0]];
    if ([entry count] > 1)
        [self setTheSynset:[entry objectAtIndex: 1]];
    else
        [self setTheSynset:nil];
    [self updateUI];
    timeTraveling = NO;
}

//*** End Private Methods

- (id)init
{
    [super init];
    wordNet = [[WordNetManager alloc] initWithBundle:[NSBundle mainBundle]];
    backStack = [[NSMutableArray alloc] init];
    [backStack retain];
    forwardStack = [[NSMutableArray alloc] init];
    [forwardStack retain];
    expandedRelations = [NSMutableSet setWithArray:[wordNet allRelations]];
    [expandedRelations retain];
    
    hierarchyData = [[NSMutableArray alloc] init];
    [hierarchyData retain];
    [hierarchyData addObject:[wordNet hypernymNounRoots]];
    
    timeTraveling =
    programResizing =
    theWordChanged =
    theSynsetChanged =
    misspelling = NO;
    return self;
}

- (void)dealloc
{
    [wordNet release];
    [spellChecker release];
    
    [theWord release];
    [senses release];
    [guesses release];
    [theSynset release];
    [expandedRelations release];
    
    [currentEntry release];
    [backStack release];
    [forwardStack release];

    [super dealloc];
}

- (void)awakeFromNib
{
    [[sensesTable mainColumn] setMaxWidth:10000];
        // Default is too short.
        
    spellChecker = [NSSpellChecker sharedSpellChecker];
    [spellChecker retain];
}

- (IBAction)back:(id)sender
{
    NSInteger location = [backStack count] - 1;
    if (location < 0)
        return;

    id entry = [backStack objectAtIndex:location];
    [entry retain];
    [backStack removeObjectAtIndex:location];
    [forwardStack addObject:currentEntry];
    [currentEntry release];
    currentEntry = entry;
    
    [self updateFromHistory:entry];
}

- (IBAction)forward:(id)sender
{
    NSInteger location = [forwardStack count] - 1;
    if (location < 0)
        return;

    id entry = [forwardStack objectAtIndex:location];
    [entry retain];
    [forwardStack removeObjectAtIndex:location];
    [backStack addObject:currentEntry];
    [currentEntry release];
    currentEntry = entry;
    
    [self updateFromHistory:entry];
}

- (IBAction)searchForWord:(id)sender
{
    if ([theWord isEqualToString:[sender stringValue]])
        return;
    [self setTheWord:[sender stringValue]];
    [self setTheSynset:nil];    
    
    [self updateUI];
}

- (IBAction)toggleHierarchyWindowVisible:(id)sender
{
    if ([[hierarchyBrowser window] isVisible])
        [[hierarchyBrowser window] orderOut:nil];
    else
        [[hierarchyBrowser window] makeKeyAndOrderFront:nil];
}

- (IBAction)addHierarchyBrowserColumn:(id)sender
{
    [hierarchyBrowser setMaxVisibleColumns:
        [hierarchyBrowser numberOfVisibleColumns] + 1];
}

- (IBAction)removeHierarchyBrowserColumn:(id)sender
{
    [hierarchyBrowser setMaxVisibleColumns:
        [hierarchyBrowser numberOfVisibleColumns] - 1];
}

//*** NSTableView Data Source and Delegate Methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == sensesTable) {
        return [senses count];
    }
    return 0;
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row
{
    return [wordNet glossForSynset:[senses objectAtIndex:row]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if (theWordChanged || theSynsetChanged)
        return;

    NSInteger row = [sensesTable selectedRow];
    if (row < 0)
        [self setTheSynset:nil];
    else
        [self setTheSynset:[senses objectAtIndex:row]];
    [self updateUI];
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell
    forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if ([[aTableColumn identifier] isEqual:@"gloss"]) {
        [aCell setWraps:YES];
    }
}

- (void)tableViewColumnDidResize:(NSNotification *)aNotification
{
    if (!programResizing)
        [self setSensesTableColumnsWidth];
}

//*** End NSTableView Data Source and Delegate Methods

//*** NSOutlineView Data Source and Delegate Methods

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (misspelling)
        return [guesses objectAtIndex:index];
    
    if (item)
        return [[wordNet dataForSynset:theSynset withRelation:item]
            objectAtIndex:index];
    return [[wordNet relationsForSynset:theSynset] objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if (misspelling)
        return NO;

    return [wordNet isRelation:item];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (misspelling)
        return [guesses count];
        
    
    if (!theSynset)
        return 0;
    if(item)
        return [[wordNet dataForSynset:theSynset withRelation:item] count];
    return [[wordNet relationsForSynset:theSynset] count];
}

- (id)outlineView:(NSOutlineView *)outlineView
    objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if (misspelling)
        return item;
        
    if ([wordNet isRelation:item])
        return [wordNet nameOfrelation:item];
    if ([item isKindOfClass:[NSNumber class]])
        return [wordNet avatarForSynset:item];
    if ([item isKindOfClass:[NSArray class]])
        return [wordNet avatarForSynset:[item objectAtIndex:0]
            atIndex:[[item objectAtIndex:1] integerValue]];
    return item;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
    if (![expandedRelations containsObject:item])
        [expandedRelations addObject:item];
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
    if ([expandedRelations containsObject:item])
        [expandedRelations removeObject:item];
    return YES;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    if (theWordChanged || theSynsetChanged)
        return;

    id item = [relationsView itemAtRow:[relationsView selectedRow]];
    
    if (!item || [relationsView isExpandable:item]
            || [[wordNet verbFrames] containsObject:item])
        return;
    
    if ([item isKindOfClass:[NSNumber class]]) {
        [self setTheSynset:item];
        [self setTheWord:[wordNet avatarForSynset:theSynset]];
    } else if ([item isKindOfClass:[NSArray class]]) {
        [self setTheSynset:[item objectAtIndex:0]];
        [self setTheWord:[wordNet avatarForSynset:theSynset
            atIndex:[[item objectAtIndex:1] integerValue]]];
    } else if ([item isKindOfClass:[NSString class]]) {
        [self setTheWord:item];
        [self setTheSynset:nil];
    }
    [self updateUI];
}

//*** End NSOutlineView Data Source and Delegate Methods

//*** NSBrowser Passive Delegate Methods

- (IBAction)browserSingleClick:(id)sender
{
    NSInteger column = [sender selectedColumn];
    NSInteger row = [sender selectedRowInColumn:column];
    
    if (column == 0 && row == [[hierarchyData objectAtIndex:column] count]) {
        [self setTheWord:@""];
        [self setTheSynset:nil];
    } else {
        [self setTheSynset:[[hierarchyData objectAtIndex:column] objectAtIndex:row]];
        [self setTheWord:[wordNet avatarForSynset:theSynset]];
    }
    [self updateUI];
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column
{
    if (column == 0)
        return [[hierarchyData objectAtIndex:0] count] + 1; // the roots
        
    if (column == 1 && [[sender selectedCellInColumn:0] stringValue] == verbsString)
        [hierarchyData setObject:[wordNet hypernymVerbRoots] forIndex:1];
    else
        [hierarchyData
            setObject:[wordNet hyponymsForSynset:
                [[hierarchyData objectAtIndex:column - 1] objectAtIndex:
                    [sender selectedRowInColumn:column - 1]]]
            forIndex:column];
    return [[hierarchyData objectAtIndex:column] count];
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell
    atRow:(NSInteger)row column:(NSInteger)column
{
    NSNumber *synset;
    NSString *avatar;
    
    if (column == 0 && (row == [[hierarchyData objectAtIndex:0] count])) {
        avatar = verbsString;
        [cell setLeaf:NO];
    } else {
        synset = [[hierarchyData objectAtIndex:column] objectAtIndex:row];
        avatar = [wordNet avatarForSynset:synset];
        [cell setLeaf:[[wordNet hyponymsForSynset: synset] count] == 0];
    }
    [cell setStringValue:avatar];
}

//*** End NSBrowser Passive Delegate Methods

//*** Service Support
- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    [NSApp setServicesProvider:self];
}

- (void)lookupFromPB:(NSPasteboard *)pb
            userData:(void *)contextData
               error:(NSString **)error
{
    NSArray *types = [pb types];
    NSString *pboardString;
    if (![types containsObject:NSStringPboardType]) {
        *error = @"No string on pasteboard";
        return;
    }
    pboardString = [pb stringForType:NSStringPboardType];
    if (!pboardString) {
        *error = @"String on pasteboard is null";
        return;
    }
    [searchField setStringValue:pboardString];
    [self searchForWord:searchField];
}
//*** End Service Support

//*** Validate Menu Item

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
    if ([anItem action] == @selector(removeHierarchyBrowserColumn:)
            && [hierarchyBrowser numberOfVisibleColumns] == 2)
        return NO;
    return YES;
}

//*** End Validate Menu Item
@end