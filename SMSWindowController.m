//
//  SMSWindowController.m
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

#import "SMSWindowController.h"
#import "BluetoothPhoneInfo.h"
#import "BluetoothCommandChannel.h"
#import "SMSSender.h"

@implementation SMSWindowController

//initialize our member variables and load the nib file for our sheet
- (SMSWindowController*)initWithNib:(NSNib*)nib
{
  self = [super init];
  if(self)
  {
    currentPhoneNumber = nil;
    if(![nib instantiateNibWithOwner:self topLevelObjects:&nibObjects])
    {
      NSLog(@"Error: could not instantiate nib");
      return nil;
    }
    [nibObjects makeObjectsPerformSelector:@selector(release)];
    [nibObjects retain];
  }
  return self;
}

- (void)runSheetForPhone:(NSString *)phoneNumber
{
  if(currentPhoneNumber) [currentPhoneNumber autorelease];
  currentPhoneNumber = phoneNumber;
  [currentPhoneNumber retain];
  [NSApp beginSheet:sendingPane modalForWindow:[NSApp mainWindow]
      modalDelegate:self didEndSelector:NULL contextInfo:nil];
  [self checkSavedTerminal];
}
//Checks if the terminal name that is saved in user defaults is present and selects it if so,
//otherwise erases the setting in defaults.
- (void)checkSavedTerminal
{
  NSString* savedTerminal = [[NSUserDefaults standardUserDefaults] stringForKey:kBluetoothSMSSerialPort];
  if(savedTerminal)
  {
    NSArray* list = [self list];
    NSUInteger portsCount = [list count];
    BOOL found = NO;
    NSUInteger i;
    for (i = 0; i < portsCount; ++i)
    {
      //compare name
      if([[[list objectAtIndex:i] name] isEqualToString:savedTerminal])
      {
        [phonePopUp selectItemAtIndex:i];
        BluetoothPhoneInfo* selectedPhone = [list objectAtIndex:i];
        found = YES;
        if(phone)
        {
          [phone release];
        }
        phone = [[SMSSender alloc] initWithDevice:selectedPhone.dev serviceUUID:selectedPhone.uuid];
        phone.delegate = self;
        break;
      }
    }
    if(!found)
    {
      [phonePopUp selectItemAtIndex:0];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBluetoothSMSSerialPort];
    }
  }  
}

//This method is called when the content of the text message field is updated
//and it recalculates the character/sms count.
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	int count = [SMSSender messageSize:[messageText stringValue]];
  if([longMessages state] == NSOnState)
  {
    [messageLabel setStringValue:[NSString stringWithFormat:@"Message Text (%d characters, using %d messages):",[[messageText stringValue] length],count]];
  }
  else
  {
    if(count > 1)
    {
      //this shouldn't happen as the formatter should prevent it
      //NSLog(@"Warning: count exceeded 1!");
      [messageText setStringValue:[[messageText stringValue] substringToIndex:160]];
    }
    [messageLabel setStringValue:[NSString stringWithFormat:@"Message Text (%d characters):",[[messageText stringValue] length]]];
  }
}

- (void)testFailed:(NSString*)message
{
  [statusSpinner stopAnimation:self];
  [statusLabel setStringValue:[NSString stringWithFormat:@"Test failed: %@",message]];
  [testingPhoneName release];
  testingPhoneName = nil;
  [self checkSavedTerminal];
}

- (void)testPassed
{
  [statusSpinner stopAnimation:self];
  [statusLabel setStringValue:@"Test succeeded"];
  [[NSUserDefaults standardUserDefaults] setObject:testingPhoneName forKey:kBluetoothSMSSerialPort];
  [testingPhoneName release];
  testingPhoneName = nil;
}

- (void)sendFailed:(NSString*)message
{
  [statusSpinner stopAnimation:self];
  [statusLabel setStringValue:[NSString stringWithFormat:@"Failed: %@",message]];
  [self enableControls];
}

- (void)sendSucceeded
{
  [statusSpinner stopAnimation:self];
  [statusLabel setStringValue:@"Sent successfully"];
  [NSTimer scheduledTimerWithTimeInterval:2
                                   target:self
                                 selector:@selector(delayedHideSheet)
                                 userInfo:nil
                                  repeats:NO];
}

- (void)statusUpdated:(NSString*)message
{
  [statusLabel setStringValue:message];
}

//cleanup and hide the sheet
- (IBAction)cancel:(id)sender
{
  [sendingPane orderOut:nil];
  [NSApp endSheet:sendingPane];
  [nibObjects release];
}

// Action fired when the user selects a port, it tests the port
- (IBAction)selectPhone:(id)sender
{
  if(![[phonePopUp titleOfSelectedItem] isEqualToString:CHOOSE_PORT_STRING])
  {
    BluetoothPhoneInfo* selectedPhone = [[popupController selectedObjects] objectAtIndex:0];
    if(phone)
    {
      [phone release];
    }
    if(testingPhoneName)
    {
      [testingPhoneName release];
    }
    phone = [[SMSSender alloc] initWithDevice:selectedPhone.dev serviceUUID:selectedPhone.uuid];
    testingPhoneName = selectedPhone.name;
    [testingPhoneName retain];
    phone.delegate = self;
    [statusLabel setHidden:NO];
    IOReturn status = [phone test];
    if(status == kIOReturnSuccess)
    {
      [statusLabel setStringValue:[NSString stringWithFormat:@"Testing %@ ...", selectedPhone.name]];
      [statusSpinner startAnimation:sender];
    }
    else
    {
      [statusLabel setStringValue:@"Failed to open for testing"];
    }
  }
  else if([[phonePopUp titleOfSelectedItem] isEqualToString:CHOOSE_PORT_STRING])
  {
    if(phone)
    {
      [phone release];
      phone = nil;
    }
    if(testingPhoneName)
    {
      [testingPhoneName release];
      testingPhoneName = nil;
    }
    [statusLabel setHidden:YES];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBluetoothSMSSerialPort];
  }
}

//Action fired when the user clicks send
- (IBAction)send:(id)sender
{
  NSString* savedTerminal = [[NSUserDefaults standardUserDefaults] stringForKey:kBluetoothSMSSerialPort];
  [statusLabel setHidden:NO];
  if(savedTerminal != nil && (![savedTerminal isEqualToString:@""]))
  {
    [self disableControls];
    [statusLabel setStringValue:@"Sending..."];
    [phone sendSMS:[messageText stringValue] to:currentPhoneNumber withReceipt:([receiptRequested state] == NSOnState)];
    [statusSpinner startAnimation:sender];
  }
  else 
  {
    [statusLabel setStringValue:@"Error: choose a valid port first!"];
  }
}

- (IBAction)longMessagesChanged:(id)sender
{
  [self controlTextDidChange:nil];
}

//disable the controls while send is in progress
- (void)disableControls
{
  [messageLabel setEnabled:NO];
  [messageText setEnabled:NO];
  [sendLabel setEnabled:NO];
  [phonePopUp setEnabled:NO];
  [longMessages setEnabled:NO];
  [receiptRequested setEnabled:NO];
  [statusLabel setEnabled:NO];
  [sendButton setEnabled:NO];
}

- (void)enableControls
{
  [messageLabel setEnabled:YES];
  [messageText setEnabled:YES];
  [sendLabel setEnabled:YES];
  [phonePopUp setEnabled:YES];
  [longMessages setEnabled:YES];
  [receiptRequested setEnabled:YES];
  [statusLabel setEnabled:YES];
  [sendButton setEnabled:YES];
}

//called to hide the sheet after a successful send
- (void)delayedHideSheet
{
  [sendingPane orderOut:nil];
  [NSApp endSheet:sendingPane];
  [nibObjects release];
}

- (void)dealloc
{
  if(phone)
  {
    [phone release];
    phone = nil;
  }
  if(testingPhoneName)
  {
    [testingPhoneName release];
    phone = nil;
  }
  if(currentPhoneNumber)
  {
    [currentPhoneNumber release];
    phone = nil;
  }
  [super dealloc];
}

//List the tty devices available
- (NSArray*)list
{
  BluetoothPhoneInfo* dummy = [[[BluetoothPhoneInfo alloc] init] autorelease];
  dummy.dev = nil;
  dummy.uuid = nil;
  dummy.name = CHOOSE_PORT_STRING;
  NSArray* phones = [NSArray arrayWithObject:dummy];
  return [phones arrayByAddingObjectsFromArray:[BluetoothCommandChannel listServices]];
}

@end

//The SMSTextFieldFormatter is a custom formatter for the text field,
//which doesn't permit the length to exceed the SMS length if long messages
//are disabled.
@implementation SMSTextFieldFormatter

- (NSString *)stringForObjectValue:(id)object {
  return (NSString *)object;
}

- (BOOL)getObjectValue:(id *)object forString:(NSString *)string errorDescription:(NSString **)error {
  *object = string;
  return YES;
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error {
  if([longMessages state] == NSOffState && [SMSSender messageSize:partialString] > 1)
  {
    *newString = nil;
    return NO;
  }
  
  return YES;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)anObject withDefaultAttributes:(NSDictionary *)attributes {
  return nil;
}

@end
