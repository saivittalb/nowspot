//
//  AppDelegate.m
//  Nowspot
//
//  Created by Sai Vittal B on 22/05/2020.
//  Copyright © 2020 Sai Vittal B. All rights reserved.
//

#import "AppDelegate.h"
#import "PFMoveApplication.h"

static NSString * const NowspotPlayerStatePreferenceKey = @"NowspotPlayerState";
static NSString * const NowspotNotificationStatePreferenceKey = @"NowspotNotificationState";
static NSString * const NowspotMenuIconPreferenceKey = @"NowspotMenuIcon";
static NSString * const NowspotStartAtLoginPreferenceKey = @"NowspotStartAtLogin";
static NSString * const NowspotStartupInformationPreferenceKey = @"NowspotStartupInformation";
static NSString * const NowspotFirstLoginKey = @"NowspotFirstLogin";

@interface AppDelegate ()

@property (nonatomic, strong) NSImage *currentAlbumArt;
@property (nonatomic, strong) NSImage *menubarImage;
@property (nonatomic, strong) NSString *currentSongName;
@property (nonatomic, strong) NSString *trackID;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenuItem *artworkMenuItem;
@property (nonatomic, strong) NSMenuItem *songMenuItem;
@property (nonatomic, strong) NSMenuItem *artistMenuItem;
@property (nonatomic, strong) NSMenuItem *albumMenuItem;
@property (nonatomic, strong) NSMenuItem *playerStateMenuItem;
@property (nonatomic, strong) NSMenuItem *notificationStateMenuItem;
@property (nonatomic, strong) NSMenuItem *menuIconMenuItem;
@property (nonatomic, strong) NSMenuItem *startAtLoginMenuItem;
@property (nonatomic) float panX;
@property (nonatomic) BOOL playing;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    PFMoveToApplicationsFolderIfNecessary();
    
    // show welcome screen
    if (![[NSUserDefaults standardUserDefaults] boolForKey:NowspotStartupInformationPreferenceKey]) {
        [self helpDialog];
    }
    
    // enable notifications by default on first startup
    if (![[NSUserDefaults standardUserDefaults] boolForKey:NowspotFirstLoginKey]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:NowspotFirstLoginKey];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:NowspotNotificationStatePreferenceKey];
    }
    
    // load menubar image
    self.menubarImage = [NSImage imageNamed:@"StatusBarIcon"];
    [self.menubarImage setTemplate:YES];
    
    // get app version
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSString *appBuild = [infoDict objectForKey:@"CFBundleVersion"];
    
    // initialize status item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    // initialize gesture recognizer
    NSPressGestureRecognizer *press = [[NSPressGestureRecognizer alloc] init];
    press.minimumPressDuration = .75;
    press.target = self;
    press.delaysPrimaryMouseButtonEvents = true;
    press.allowableMovement = 50;
    press.action = @selector(longPressHandler:);
    NSPanGestureRecognizer *pan = [[NSPanGestureRecognizer alloc] init];
    pan.action = @selector(panHandler:);
    pan.target = self;
    [self.statusItem.button addGestureRecognizer:press];
    [self.statusItem.button addGestureRecognizer:pan];
    
    // initialize menu containers
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Nowspot"];
    NSMenu *optionsSubmenu = [[NSMenu alloc] initWithTitle:@"Options"];
    NSMenuItem *optionsMenu = [[NSMenuItem alloc] initWithTitle:@"Options" action:nil keyEquivalent:@""];
    
    // initialize main menu items
    self.artworkMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.songMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.artistMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.albumMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    
    // initialize options menu items
    self.playerStateMenuItem = [[NSMenuItem alloc] initWithTitle:@"View play icon in menubar" action:[[NSUserDefaults standardUserDefaults] boolForKey:NowspotMenuIconPreferenceKey]?nil:@selector(togglePlayerState) keyEquivalent:@""];
    self.playerStateMenuItem.toolTip = @"Show a play icon in the menu bar when song is playing";
    self.playerStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey];
    self.notificationStateMenuItem = [[NSMenuItem alloc] initWithTitle:@"Song notifications" action:@selector(toggleNotifications) keyEquivalent:@""];
    self.notificationStateMenuItem.toolTip = @"Get a notification when a new song comes on";
    self.notificationStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:NowspotNotificationStatePreferenceKey];
    self.menuIconMenuItem = [[NSMenuItem alloc] initWithTitle:@"Hide text in menubar" action:@selector(toggleMenuIcon) keyEquivalent:@""];
    self.menuIconMenuItem.toolTip = @"Replaces song title with an icon to save space in the menu bar";
    self.menuIconMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:NowspotMenuIconPreferenceKey];
    self.startAtLoginMenuItem = [[NSMenuItem alloc] initWithTitle:@"Start at login" action:@selector(toggleStartAtLogin) keyEquivalent:@""];
    self.startAtLoginMenuItem.toolTip = @"Automatically launch Nowspot when starting up your computer";
    self.startAtLoginMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:NowspotStartAtLoginPreferenceKey];
    
    // set up menus
    [mainMenu addItem:self.artworkMenuItem];
    [mainMenu addItem:self.songMenuItem];
    [mainMenu addItem:self.artistMenuItem];
    [mainMenu addItem:self.albumMenuItem];
    [mainMenu addItem:[NSMenuItem separatorItem]];
    [optionsMenu setSubmenu:optionsSubmenu];
    [optionsSubmenu addItem:self.playerStateMenuItem];
    [optionsSubmenu addItem:self.notificationStateMenuItem];
    [optionsSubmenu addItem:self.menuIconMenuItem];
    [optionsSubmenu addItem:self.startAtLoginMenuItem];
    [mainMenu addItem:optionsMenu];
    [mainMenu addItemWithTitle:@"Help" action:@selector(helpDialog) keyEquivalent:@"h"];
    [mainMenu addItemWithTitle:@"Donate" action:@selector(donate) keyEquivalent:@"d"];
    [mainMenu addItemWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@"q"];
    [mainMenu addItem:[NSMenuItem separatorItem]];
    [mainMenu addItemWithTitle:@"Nowspot" action:nil keyEquivalent:@""];
    NSMenuItem *versionMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"v%@ by Sai Vittal B", appVersion] action:nil keyEquivalent:@""];
    versionMenuItem.toolTip = [NSString stringWithFormat:@"Build %@", appBuild];
    [mainMenu addItem:versionMenuItem];
    [self.statusItem setMenu:mainMenu];
    
    // initialize song
    @try {
        self.trackID = [[NSString alloc] initWithString:[[self executeAppleScript:@"get id of current track"] stringValue]];
        self.playing = [[[self executeAppleScript:@"get player state"] stringValue] isEqualToString:@"kPSP"];
        self.currentSongName = [[NSString alloc] initWithString:[[self executeAppleScript:@"get name of current track"] stringValue]];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:NowspotMenuIconPreferenceKey]){
            self.statusItem.button.title = ([[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey] && self.playing)?[NSString stringWithFormat:@"%@ ►",[self shortenedSongName]]:[self shortenedSongName];
            if (self.statusItem.button.title != nil && ![self.statusItem.button.title isEqualToString:(@"")] )
                self.statusItem.button.image = nil;
            else
                self.statusItem.button.image = self.menubarImage;
        }
        else {
            self.statusItem.button.title = @"";
            self.statusItem.button.image = self.menubarImage;
        }
        self.songMenuItem.title = self.currentSongName;
        self.artistMenuItem.title = [[self executeAppleScript:@"get artist of current track"] stringValue];
        self.albumMenuItem.title =[[self executeAppleScript:@"get album of current track"] stringValue];
        self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@\n%@\n%@",self.currentSongName,self.artistMenuItem.title,self.albumMenuItem.title];
        [self setImage];
        [self showNotification];
        
    }
    @catch (NSException *e) {
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
        self.trackID = @"";
        self.currentSongName = @"";
        self.currentAlbumArt = nil;
        self.artworkMenuItem.image = nil;
        self.artworkMenuItem.title = @"";
        self.artworkMenuItem.action = @selector(launchSpotify);
        self.songMenuItem.title = @"Spotify is not running.";
        self.artistMenuItem.title = @"Click here to open Spotify.";
        self.albumMenuItem.title = @"";
        self.playing = NO;
        self.statusItem.button.toolTip = @"Nowspot";
    }
    
    // set up notification center
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:) name:@"com.spotify.client.PlaybackStateChanged" object:nil];
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self quit];
}

#pragma mark - helper functions

- (void)helpDialog
{
    NSAlert *alert = [[NSAlert alloc] init];
    {
        [alert setMessageText:@"Welcome to Nowspot!"];
        [alert setInformativeText:@"Nowspot gives you easy access to see what song is playing in Spotify!\n\nHelp:\nClick on Nowspot up in the menu bar to see information about the song that's currently playing.\nClick and hold to play/pause, and click and drag right/left to skip/go back.\n\nOptions:\nView play icon in menu bar: Show a play icon in the menu bar when song is playing.\nSong notifications: Get a notification when a new song comes on.\nHide text in menu bar: Replaces song title with an icon to save space in the menu bar.\nStart at login: Automatically launch Nowspot when starting up your computer.\n\nDonate:\nI build everything for free and will continue to build free. It'd be great if you can help me by buying a coffee.\n\nEnjoy!\n- Sai Vittal B"];
        [alert addButtonWithTitle:@"Okay"];
        [alert setShowsSuppressionButton:YES];
        NSCell *cell = [[alert suppressionButton] cell];
        [cell setControlSize:NSControlSizeSmall];
        [cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        [cell setState:[[NSUserDefaults standardUserDefaults] boolForKey:NowspotStartupInformationPreferenceKey]];
        [alert runModal];
        if ([[alert suppressionButton] state] == NSControlStateValueOn)
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:NowspotStartupInformationPreferenceKey];
        else
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:NowspotStartupInformationPreferenceKey];
    }
}

- (void)donate
{
    NSURL *URL = [NSURL URLWithString:@"https://www.paypal.me/saivittalb33"];
    [[NSWorkspace sharedWorkspace]openURL:URL];
}

- (void)playbackStateChanged:(NSNotification *)aNotification
{
    if ([[[aNotification userInfo] objectForKey:@"Player State"] isEqualToString:@"Stopped"]) {
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
        self.trackID = @"";
        self.currentSongName = @"";
        self.currentAlbumArt = nil;
        self.artworkMenuItem.image = nil;
        self.artworkMenuItem.title = @"";
        self.artworkMenuItem.action = @selector(launchSpotify);
        self.songMenuItem.title = @"Spotify is not running.";
        self.artistMenuItem.title = @"Click here to open Spotify.";
        self.albumMenuItem.title = @"";
        self.playing = NO;
        self.statusItem.button.toolTip = @"Nowspot";
    }
    else {
        self.playing = [[[aNotification userInfo] objectForKey:@"Player State"] isEqualToString:@"Playing"];
        if (![[[aNotification userInfo] objectForKey:@"Track ID"] isEqualToString:self.trackID]
            || ![[[aNotification userInfo] objectForKey:@"Name"] isEqualToString:self.currentSongName]) {
            self.trackID = [[aNotification userInfo] objectForKey:@"Track ID"];
            [self setImage];
            self.currentSongName = [[aNotification userInfo] objectForKey:@"Name"];
            if (![[NSUserDefaults standardUserDefaults] boolForKey:NowspotMenuIconPreferenceKey]){
                self.statusItem.button.title = ([[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey] && self.playing)?[NSString stringWithFormat:@"%@ ►",[self shortenedSongName]]:[self shortenedSongName];
                if (self.statusItem.button.title != nil && ![self.statusItem.button.title isEqualToString:(@"")] )
                    self.statusItem.button.image = nil;
                else
                    self.statusItem.button.image = self.menubarImage;
            }
            self.songMenuItem.title = self.currentSongName;
            self.artistMenuItem.title = [[aNotification userInfo] objectForKey:@"Artist"];
            self.albumMenuItem.title = [[aNotification userInfo] objectForKey:@"Album"];
            self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@\n%@\n%@",self.currentSongName,self.artistMenuItem.title,self.albumMenuItem.title];
            [self showNotification];
        }
        else {
            if (![[NSUserDefaults standardUserDefaults] boolForKey:NowspotMenuIconPreferenceKey])
                self.statusItem.button.title = ([[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey] && self.playing)?[NSString stringWithFormat:@"%@ ►",[self shortenedSongName]]:[self shortenedSongName];

        }
    }
}

- (void)togglePlayerState
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey] forKey:NowspotPlayerStatePreferenceKey];
    self.playerStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey] && self.playing)
        self.statusItem.button.title = [NSString stringWithFormat:@"%@ ►", self.statusItem.button.title];
    else if (![[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey] && self.playing)
        self.statusItem.button.title = [self shortenedSongName];
}

- (void)toggleNotifications
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:NowspotNotificationStatePreferenceKey] forKey:NowspotNotificationStatePreferenceKey];
    self.notificationStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:NowspotNotificationStatePreferenceKey];
}

- (void)toggleMenuIcon
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:NowspotMenuIconPreferenceKey] forKey:NowspotMenuIconPreferenceKey];
    self.menuIconMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:NowspotMenuIconPreferenceKey];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:NowspotMenuIconPreferenceKey]) {
        self.playerStateMenuItem.action = nil;
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
    }
    else {
        self.playerStateMenuItem.action = @selector(togglePlayerState);
        if ([self.currentSongName length]){
            self.statusItem.button.image = nil;
            self.statusItem.button.title = ([[NSUserDefaults standardUserDefaults] boolForKey:NowspotPlayerStatePreferenceKey] && self.playing)?[NSString stringWithFormat:@"%@ ►",[self shortenedSongName]]:[self shortenedSongName];
        }
    }
}

- (void)toggleStartAtLogin
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:NowspotStartAtLoginPreferenceKey] forKey:NowspotStartAtLoginPreferenceKey];
    self.startAtLoginMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:NowspotStartAtLoginPreferenceKey];
    [self setLoginItem];
}

- (void) setLoginItem
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:NowspotStartAtLoginPreferenceKey])
        [self enableLoginItem];
    else
        [self disableLoginItem];
}

- (NSAppleEventDescriptor *)enableLoginItem
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"System Events\" to make login item at end with properties {path:\"%@\", hidden:false}", [[NSBundle mainBundle] bundlePath]]];
    return [script executeAndReturnError:NULL];
}

- (NSAppleEventDescriptor *)disableLoginItem
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to delete login item \"Nowspot\""];
    return [script executeAndReturnError:NULL];
}

- (void)showNotification
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:NowspotNotificationStatePreferenceKey])
        return;
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    
    notification.title = self.currentSongName;
    notification.subtitle = self.artistMenuItem.title;
    notification.informativeText = self.albumMenuItem.title;
    notification.soundName = nil;
    
    [notification setValue:@YES forKey:@"_showsButtons"];
    [notification setValue:@YES forKey:@"_ignoresDoNotDisturb"];
    
    notification.hasActionButton = true;
    notification.actionButtonTitle = @"Skip";
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    center = nil;
    notification = nil;
    return true;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    center = nil;

    NSUserNotificationActivationType num = notification.activationType;
    
    
    if(num == NSUserNotificationActivationTypeActionButtonClicked)
    {
        [self executeAppleScript:@"next track"];
    }
    else if (num == NSUserNotificationActivationTypeContentsClicked)
    {
        [[NSWorkspace sharedWorkspace] launchApplication:@"Spotify.app"];
    }
    
}

- (NSString *)shortenedSongName
{
    NSString *nameText = [NSString stringWithString:self.currentSongName];
    for (NSUInteger i = 1; i<[nameText length]; i++) {
        unichar letter = [nameText characterAtIndex:i];
        if ((letter == '-' || letter == '(' || letter == '[' || letter == '/') && [nameText characterAtIndex:(i-1)] == ' ') {
            nameText = [nameText substringToIndex:i];
            break;
        }
    }
    return nameText;
}

- (void)launchSpotify
{
    [[NSWorkspace sharedWorkspace] launchApplication:@"Spotify.app"];
}

- (void)longPressHandler:(NSGestureRecognizer*)sender
{
    if(sender.state == NSGestureRecognizerStateBegan){
        [self executeAppleScript:@"playpause"];
    }
}

- (void)panHandler:(NSPanGestureRecognizer*)sender
{
    if(sender.state == NSGestureRecognizerStateBegan){
        self.panX = 0.0;
    }
    self.panX += [sender velocityInView:sender.view].x;
    if(sender.state == NSGestureRecognizerStateEnded){
        if(self.panX > 3000){
            [self executeAppleScript:@"next track"];
        }
        else if (self.panX < -3000)
        {
            [self executeAppleScript:@"previous track"];
        }
    }
}

- (void)setImage
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://embed.spotify.com/oembed/?url=%@", self.trackID]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            self.artworkMenuItem.image = nil;
            self.artworkMenuItem.title = @"Could not load album artwork";
            self.artworkMenuItem.action = @selector(setImage);
            self.artworkMenuItem.toolTip = @"Click to try again";
        }
        else {
            NSMutableDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            NSURL *imageUrl = [NSURL URLWithString:parsedData[@"thumbnail_url"]];
            NSURLRequest *imageUrlRequest = [NSURLRequest requestWithURL:imageUrl];
            NSURLSession *imageSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            NSURLSessionDataTask *imageTask = [imageSession dataTaskWithRequest:imageUrlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    self.artworkMenuItem.image = nil;
                    self.artworkMenuItem.title = @"Could not load album artwork";
                    self.artworkMenuItem.action = @selector(setImage);
                    self.artworkMenuItem.toolTip = @"Click to try again";

                }
                else {
                    self.currentAlbumArt = [[NSImage alloc] initWithData:data];
                    self.currentAlbumArt.size = CGSizeMake(200, 200);
                    self.artworkMenuItem.image = self.currentAlbumArt;
                    self.artworkMenuItem.title = @"";
                    self.artworkMenuItem.action = @selector(launchSpotify);
                    self.artworkMenuItem.toolTip = nil;

                }
            }];
            [imageTask resume];
        }
    }];
    [task resume];
}

- (NSAppleEventDescriptor *)executeAppleScript:(NSString *)command
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"if application \"Spotify\" is running then tell application \"Spotify\" to %@", command]];
    return [script executeAndReturnError:NULL];
}

- (void)quit
{
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    [[NSApplication sharedApplication] terminate:self];
}
@end
