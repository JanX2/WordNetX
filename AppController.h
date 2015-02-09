//
//  AppController.h
//  WordNetX
//
//  Created by William Taysom on Mon Aug 25 2003.
//

#import <Cocoa/Cocoa.h>
#import "WordNetTableView.h"
#import "WordNetManager.h"

@interface NSTableView (NSTableViewExtentionForWordNetX)
@property (nonatomic, readonly, strong) NSTableColumn *mainColumn;
@end

@interface NSMutableArray (NSMutableArrayExtentionForWordNetX)
- (void)setObject:(id)object forIndex:(NSInteger)index;
@end

@interface AppController : NSObject {

    IBOutlet NSTextField *searchField;
    IBOutlet NSButton *backButton;
    IBOutlet NSButton *forwardButton;
    IBOutlet WordNetTableView *sensesTable;
    IBOutlet NSOutlineView *relationsView;
    IBOutlet NSBrowser *hierarchyBrowser;
        
    WordNetManager *wordNet;
    NSSpellChecker *spellChecker;
    
    NSString *theWord;
    NSArray *senses, *guesses;
    NSNumber *theSynset;
    NSMutableSet *expandedRelations;
    
    NSObject *currentEntry;
    NSMutableArray *backStack;
    NSMutableArray *forwardStack;
    
    NSMutableArray *hierarchyData;
    
    BOOL timeTraveling;
    BOOL programResizing;
    BOOL theWordChanged;
    BOOL theSynsetChanged;
    BOOL misspelling;
}
- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)searchForWord:(id)sender;

- (IBAction)toggleHierarchyWindowVisible:(id)sender;
- (IBAction)browserSingleClick:(id)sender;
- (IBAction)addHierarchyBrowserColumn:(id)sender;
- (IBAction)removeHierarchyBrowserColumn:(id)sender;
@end
