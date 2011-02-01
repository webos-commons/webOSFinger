//
//  SimFingerAppDelegate.m
//  SimFinger
//
//  Created by Loren Brichter on 2/11/09.
//  Copyright 2009 atebits. All rights reserved.
//

#import "FakeFingerAppDelegate.h"
#import <Carbon/Carbon.h>

void WindowFrameDidChangeCallback( AXObserverRef observer, AXUIElementRef element, CFStringRef notificationName, void * contextData)
{
    FakeFingerAppDelegate * delegate= (FakeFingerAppDelegate *) contextData;
	[delegate positionSimulatorWindow:nil];
}

@implementation FakeFingerAppDelegate

- (void)registerForSimulatorWindowResizedNotification
{
	// this methode is leaking ...
	
	AXUIElementRef simulatorApp = [self simulatorApplication];
	if (!simulatorApp) return;
	
	AXUIElementRef frontWindow = NULL;
	AXError err = AXUIElementCopyAttributeValue( simulatorApp, kAXFocusedWindowAttribute, (CFTypeRef *) &frontWindow );
	if ( err != kAXErrorSuccess ) return;

	AXObserverRef observer = NULL;
	pid_t pid;
	AXUIElementGetPid(simulatorApp, &pid);
	err = AXObserverCreate(pid, WindowFrameDidChangeCallback, &observer );
	if ( err != kAXErrorSuccess ) return;
	
	AXObserverAddNotification( observer, frontWindow, kAXResizedNotification, self );
	AXObserverAddNotification( observer, frontWindow, kAXMovedNotification, self );

	CFRunLoopAddSource( [[NSRunLoop currentRunLoop] getCFRunLoop],  AXObserverGetRunLoopSource(observer),  kCFRunLoopDefaultMode );
		
}

- (AXUIElementRef)simulatorApplication
{
	if(AXAPIEnabled())
	{
		NSArray *applications = [[NSWorkspace sharedWorkspace] launchedApplications];
		
		for(NSDictionary *application in applications)
		{
			//	NSLog(@"Open App: %@", [application valueForKey:@"NSApplicationBundleIdentifier"]);
			if([[application valueForKey:@"NSApplicationBundleIdentifier"] isEqualToString:@"org.virtualbox.app.VirtualBoxVM"])
			{
				pid_t pid = (pid_t)[[application objectForKey:@"NSApplicationProcessIdentifier"] integerValue];
				
				[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:[application objectForKey:@"NSApplicationBundleIdentifier"] 
																	 options:NSWorkspaceLaunchDefault 
											  additionalEventParamDescriptor:nil 
															launchIdentifier:nil];
				
				AXUIElementRef element = AXUIElementCreateApplication(pid);
				return element;
			}
		}
	} else {
		NSRunAlertPanel(@"Universal Access Disabled", @"You must enable access for assistive devices in the System Preferences, under Universal Access.", @"OK", nil, nil, nil);
	}
	NSRunAlertPanel(@"Couldn't find Emulator", @"You must have the webOS Emulator running in order to use this application.", @"OK", nil, nil, nil);
	[NSApp terminate: nil];
	return NULL;
}

- (void)positionSimulatorWindow:(id)sender
{
	AXUIElementRef element = [self simulatorApplication];
	
	CFArrayRef attributeNames;
	AXUIElementCopyAttributeNames(element, &attributeNames);
	
	CFArrayRef value;
	AXUIElementCopyAttributeValue(element, CFSTR("AXWindows"), (CFTypeRef *)&value);
	
	for(id object in (NSArray *)value)
	{
		if(CFGetTypeID(object) == AXUIElementGetTypeID())
		{
			AXUIElementRef subElement = (AXUIElementRef)object;
			
			AXUIElementPerformAction(subElement, kAXRaiseAction);
			
			CFArrayRef subAttributeNames;
			AXUIElementCopyAttributeNames(subElement, &subAttributeNames);
			
			CFTypeRef sizeValue;
			AXUIElementCopyAttributeValue(subElement, kAXSizeAttribute, (CFTypeRef *)&sizeValue);
			
			CGSize size;
			AXValueGetValue(sizeValue, kAXValueCGSizeType, (void *)&size);
			
			NSLog(@"Emulator current size: %d, %d", (int)size.width, (int)size.height);
						
			BOOL supportedSize = NO;
			BOOL Pre = NO;
			BOOL Pixi = NO;

			int PreWidth = 320;
			int PreHeight = 524;
			
			int PixiWidth = 320;
			int PixiHeight = 444;
				
			//------
			//THIS IS WHERE YOU SET THE DEVICE FRAME/LOCATION (0,0)
			//------
			if((int)size.width == PreWidth && (int)size.height == PreHeight)
			{
				[hardwareOverlay setContentSize:NSMakeSize(498,759)];
				[hardwareOverlay setBackgroundColor: [NSColor colorWithPatternImage:[NSImage imageNamed:@"PreFrame"]]];
				supportedSize = YES;
				Pre = YES;
				NSLog(@"Emulator is a Pre.");
			}
			else if((int)size.width == PixiWidth && (int)size.height == PixiHeight)
			{
				[hardwareOverlay setContentSize:NSMakeSize(498,900)];
				[hardwareOverlay setBackgroundColor: [NSColor colorWithPatternImage:[NSImage imageNamed:@"PixiFrame"]]];
				supportedSize = YES;
				Pixi = YES;
				NSLog(@"Emulator is a Pixi.");
			
				//old code to reposition simfinger frame
				//NSPoint newOrigin;
				//newOrigin.x = 0;
				//newOrigin.y = -140;
				//[hardwareOverlay setFrameOrigin:newOrigin];
			}
			
			if(supportedSize)
			{
				Boolean settable;
				AXUIElementIsAttributeSettable(subElement, kAXPositionAttribute, &settable);
				
				CGPoint point;
				//------				
				//THIS IS WHERE YOU SET THE EMULATOR OFFSETS!!!
				//------
				if (Pre)
				{
					point.x = 75+9;
					point.y = screenRect.size.height - size.height - 145;
				}
				else if (Pixi)
				{
					point.x = 75+9;
					point.y = screenRect.size.height - size.height - 365;
				}
				
				AXValueRef pointValue = AXValueCreate(kAXValueCGPointType, &point);
				
				AXUIElementSetAttributeValue(subElement, kAXPositionAttribute, (CFTypeRef)pointValue);
			}							
			
		}
	}
}


- (void)_updateWindowPosition
{
	NSPoint p = [NSEvent mouseLocation];
	[pointerOverlay setFrameOrigin:NSMakePoint(p.x - 25, p.y - 25)];
}

- (void)mouseDown
{
	[pointerOverlay setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"Active"]]];
}

- (void)mouseUp
{
	[pointerOverlay setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"Hover"]]];
}

- (void)mouseMoved
{
	[self _updateWindowPosition];
}

- (void)mouseDragged
{
	[self _updateWindowPosition];
}




- (void)configureHardwareOverlay:(NSMenuItem *)sender
{
	if(hardwareOverlayIsHidden) {
		[hardwareOverlay orderFront:nil];
		[fadeOverlay orderFront:nil];
		[sender setState:NSOffState];
	} else {
		[hardwareOverlay orderOut:nil];
		[fadeOverlay orderOut:nil];
		[sender setState:NSOnState];
	}
	hardwareOverlayIsHidden = !hardwareOverlayIsHidden;
}

- (void)configurePointerOverlay:(NSMenuItem *)sender
{
	if(pointerOverlayIsHidden) {
		[pointerOverlay orderFront:nil];
		[sender setState:NSOffState];
	} else {
		[pointerOverlay orderOut:nil];
		[sender setState:NSOnState];
	}
	pointerOverlayIsHidden = !pointerOverlayIsHidden;
}


CGEventRef tapCallBack(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *info)
{
	FakeFingerAppDelegate *delegate = (FakeFingerAppDelegate *)info;
	switch(type)
	{
		case kCGEventLeftMouseDown:
			[delegate mouseDown];
			break;
		case kCGEventLeftMouseUp:
			[delegate mouseUp];
			break;
		case kCGEventLeftMouseDragged:
			[delegate mouseDragged];
			break;
		case kCGEventMouseMoved:
			[delegate mouseMoved];
			break;
	}
	return event;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	//iphone 634, 985
	//pre 498,759

	hardwareOverlay = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1, 1) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[hardwareOverlay setAlphaValue:1.0];
	[hardwareOverlay setOpaque:NO];
	//removed so we dont get a flicker when emulator is a pixi
		//[hardwareOverlay setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"PreFrame"]]];
	[hardwareOverlay setIgnoresMouseEvents:YES];
	[hardwareOverlay setLevel:NSFloatingWindowLevel - 1];
	[hardwareOverlay orderFront:nil];
	
	screenRect = [[hardwareOverlay screen] frame];
	
	pointerOverlay = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 50, 50) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[pointerOverlay setAlphaValue:0.8];
	[pointerOverlay setOpaque:NO];
	[pointerOverlay setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"Hover"]]];
	[pointerOverlay setLevel:NSFloatingWindowLevel];
	[pointerOverlay setIgnoresMouseEvents:YES];
	[self _updateWindowPosition];
	[pointerOverlay orderFront:nil];
	
	// this needs to be finished, we changed the sizing of the device frames so we need to fix the fade frames before we can enable this code
	
	/*
	fadeOverlay = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 0, 0) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[fadeOverlay setAlphaValue:1.0];
	[fadeOverlay setOpaque:NO];
	[fadeOverlay setBackgroundColor:[NSColor colorWithPatternImage:[NSImage imageNamed:@"FadeFrame"]]];
	[fadeOverlay setIgnoresMouseEvents:YES];
	[fadeOverlay setLevel:NSFloatingWindowLevel + 1];
	[fadeOverlay orderFront:nil];
	*/
	CGEventMask mask =	CGEventMaskBit(kCGEventLeftMouseDown) | 
						CGEventMaskBit(kCGEventLeftMouseUp) | 
						CGEventMaskBit(kCGEventLeftMouseDragged) | 
						CGEventMaskBit(kCGEventMouseMoved);

	CFMachPortRef tap = CGEventTapCreate(kCGAnnotatedSessionEventTap,
									kCGTailAppendEventTap,
									kCGEventTapOptionListenOnly,
									mask,
									tapCallBack,
									self);
	
	CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(NULL, tap, 0);
	CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
	
	CFRelease(runLoopSource);
	CFRelease(tap);
	
	[self registerForSimulatorWindowResizedNotification];
	[self positionSimulatorWindow:nil];
	NSLog(@"Repositioned emulator window.");
}

@end
