//
//  SMSWindowController.h
//  smsPlugin
//
//  Created by Hugh Cole-Baker on 14/09/2009.
// Copyright (c) 2009 Hugh Cole-Baker
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Cocoa/Cocoa.h>
#import "SMSSender.h"

#define CHOOSE_PORT_STRING @"choose port"
#define kBluetoothSMSSerialPort @"BluetoothSMSSerialPort"

@interface SMSWindowController : NSObject <SMSSenderDelegate> {
  IBOutlet NSWindow* sendingPane;
  IBOutlet NSPopUpButton* phonePopUp;
  IBOutlet NSProgressIndicator* statusSpinner;
  IBOutlet NSTextField* statusLabel;
  IBOutlet NSTextField* messageText;
  IBOutlet NSButton* receiptRequested;
  IBOutlet NSTextField* messageLabel;
  IBOutlet NSButton* longMessages;
  IBOutlet NSTextField* sendLabel;
  IBOutlet NSButton* sendButton;
  IBOutlet NSButton* cancelButton;
  IBOutlet NSArrayController* popupController;
  
  NSArray* nibObjects;
  NSString* testingPhoneName;
  NSString* currentPhoneNumber;
  SMSSender* phone;
  BOOL testing;
}

#pragma mark Init methods
- (SMSWindowController*)initWithNib:(NSNib*)nib;
- (void)runSheetForPhone:(NSString*)phoneNumber;

#pragma mark Misc methods
- (void)checkSavedTerminal;
- (void)disableControls;
- (void)enableControls;

#pragma mark Delegate methods
- (void)controlTextDidChange:(NSNotification *)aNotification;

- (void)testFailed:(NSString*)message;
- (void)testPassed;
- (void)sendFailed:(NSString*)message;
- (void)sendSucceeded;
- (void)statusUpdated:(NSString*)message;

#pragma mark IBActions
- (IBAction)cancel:(id)sender;
- (IBAction)selectPhone:(id)sender;
- (IBAction)send:(id)sender;
- (IBAction)longMessagesChanged:(id)sender;

- (NSArray*)list;

@end

@interface SMSTextFieldFormatter : NSFormatter {
  IBOutlet NSButton* longMessages;
}

- (NSString *)stringForObjectValue:(id)object;
- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error;
- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error;
- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes;

@end


