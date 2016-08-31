// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "Sift.h"

#import "SFAppEventsReporter.h"

static NSString * const ROOT_VIEW_CONTROLLER_TITLE = @"root_view_controller_title";

@implementation SFAppEventsReporter {
    NSOperationQueue *_queue;
    NSHashTable *_windows;
    NSHashTable *_buttons;
    NSString *_rootViewControllerKeyPath;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [NSOperationQueue new];

        NSNotificationCenter *notification = [NSNotificationCenter defaultCenter];

        // Application foreground/background.
        for (NSString *name in @[UIApplicationDidBecomeActiveNotification, UIApplicationDidEnterBackgroundNotification]) {
            [notification addObserverForName:name object:nil queue:_queue usingBlock:^(NSNotification *note) {
                SF_DEBUG(@"Notified with \"%@\"", note.name);
                [[Sift sharedInstance] appendEvent:[SFEvent eventWithType:note.name path:nil fields:nil]];
            }];
        }

        // Key window root view controller title.
        [notification addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:_queue usingBlock:^(NSNotification *note) {
            UIWindow *window = note.object;
            NSString *title = window.rootViewController.title;
            SF_DEBUG(@"Notified with \"%@\" title \"%@\"", note.name, title);
            if (title) {
                [[Sift sharedInstance] appendEvent:[SFEvent eventWithType:note.name path:nil fields:@{ROOT_VIEW_CONTROLLER_TITLE: title}]];
            }
        }];

        // TODO(clchiou): Observe new window creation/deletion and
        // subscribe/unsubscribe KVO observation (I am not sure if it is
        // possible to observe window deletion).  Since it is rare that
        // an app will create a new window, we leave this as a TODO.
        _windows = [NSHashTable weakObjectsHashTable];
        _rootViewControllerKeyPath = NSStringFromSelector(@selector(rootViewController));
        NSString *keyPath = NSStringFromSelector(@selector(rootViewController));
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            [self addObserverToWindow:window];
        }

        // Walk down UIView hierarchy and find all buttons for observation.
        _buttons = [NSHashTable weakObjectsHashTable];
        [notification addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:_queue usingBlock:^(NSNotification *note) {
            UIWindow *window = note.object;
            [self findAndAddObserverToButton:window.rootViewController.view];
        }];
    }
    return self;
}

- (void)dealloc {
    for (UIWindow *window in _windows) {
        [window removeObserver:self forKeyPath:_rootViewControllerKeyPath];
    }
    //[super dealloc];  // Provided by the compiler.
}

- (void)addObserverToWindow:(UIWindow *)window {
    if ([_windows containsObject:window]) {
        return;
    }

    // Observe rootViewController changes with KVO - not sure if this is a good idea.
    SF_DEBUG(@"Add window to KVO observation: %@ title=%@", window, window.rootViewController.title);
    [window addObserver:self forKeyPath:_rootViewControllerKeyPath options:0 context:nil];
    [self observeWindowTitle:window.rootViewController.title];
    [_windows addObject:window];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    SF_DEBUG(@"Notified with KVO change: %@.%@", ((NSObject *)object).class, keyPath);
    if ([object isKindOfClass:UIWindow.class] && [keyPath isEqualToString:NSStringFromSelector(@selector(rootViewController))]) {
        NSString *title = ((UIWindow *)object).rootViewController.title;
        SF_DEBUG(@"Window title change: %@ %@", object, title);
        [self observeWindowTitle:title];
    }
}

- (void)observeWindowTitle:(NSString *)title {
    if (title) {
        [[Sift sharedInstance] appendEvent:[SFEvent eventWithType:@"UIWindowDidChangeRootViewControllerTitle" path:nil fields:@{ROOT_VIEW_CONTROLLER_TITLE: title}]];
    }
}

- (void)findAndAddObserverToButton:(UIView *)view {
    if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;
        if (![_buttons containsObject:button]) {
            SF_DEBUG(@"Add button to observation: %@", button);
            [button addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
            [_buttons addObject:button];
        }
    }
    for (UIView *subview in view.subviews) {
        [self findAndAddObserverToButton:subview];
    }
}

- (IBAction)buttonClicked:(id)sender {
    UIButton *button = (UIButton *)sender;
    SF_DEBUG(@"Button clicked: %@ currentTitle=%@", button, button.currentTitle);
    if (button.currentTitle) {
        [[Sift sharedInstance] appendEvent:[SFEvent eventWithType:@"UIControlEventTouchUpInside" path:nil fields:@{@"button_current_title": button.currentTitle}]];
    }
}

@end
