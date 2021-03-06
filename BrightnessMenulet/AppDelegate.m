//
//  AppDelegate.m
//  BrightnessMenulet
//
//  Created by Kalvin Loc on 10/10/14.
//
//

#import "AppDelegate.h"

#import "LMUController.h"

@interface AppDelegate ()

@property NSStatusItem *statusItem;

@property (strong) IBOutlet MainMenuController *mainMenu;
@property (strong) LMUController* lmuController;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Set Menulet Icon
    NSBundle *bundle = [NSBundle mainBundle];
    NSImage *statusImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"icon" ofType:@"png"]];
    NSImage *statusHighlightImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"icon-alt" ofType:@"png"]];
    statusImage.template = YES; // Set icon as template for dark mode
    statusHighlightImage.template = YES;

    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    _statusItem.image = statusImage;
    _statusItem.alternateImage = statusHighlightImage;
    _statusItem.toolTip = @"Brightness Menulet";
    _statusItem.highlightMode = YES;
    _statusItem.menu = _mainMenu;

    // init _mainMenu
    [_mainMenu refreshMenuScreens];

    _lmuController = [[LMUController alloc] initWithDelegate:_mainMenu];
    _mainMenu.lmuController = _lmuController;
}

- (void)applicationDidChangeScreenParameters:(NSNotification *)notification {
    NSLog(@"AppDelegate: DidChangeScreenParameters");

    // BUG May crash if displays are connected/disconnected quickly so lets try waiting
    [NSThread sleepForTimeInterval:2.0f];
    [_mainMenu refreshMenuScreens];
}

@end
