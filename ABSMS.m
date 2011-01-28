//
//  ABSMS.m
//  ABSMS
//
//  Created by Hugh Cole-Baker on 12/09/2009.
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

#import "ABSMS.h"
#import "SMSWindowController.h"

extern unsigned mt_count(char const* utf8_message);

@implementation ABSMS

- (ABSMS*)init
{
  self = [super init];
  if(self)
  {
    ABPane = [[NSNib alloc] initWithNibNamed:@"ABPane" bundle:[NSBundle bundleForClass:[self class]]];
  }
  return self;
}

// This action works with phone numbers.
- (NSString *)actionProperty
{
  return kABPhoneProperty;
}


// Our title is a constant
- (NSString *)titleForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
  return @"Send SMS via Bluetooth";
}

// This method is called when the context menu item is selected
- (void)performActionForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
  //SMSWindowController must perform its own memory managment
  //as we do not get notified when it is closed
  SMSWindowController* sheet = [[SMSWindowController alloc] initWithNib:ABPane];
  ABMultiValue* values = [person valueForProperty:[self actionProperty]];
  NSString* phoneno = [values valueForIdentifier:identifier];
#ifdef DEBUG
  NSLog(@"Filtering phoneno \"%@\"",phoneno);
#endif
  phoneno = 
  [[phoneno componentsSeparatedByCharactersInSet:
    [NSCharacterSet characterSetWithCharactersInString:@" -().,"]]
   componentsJoinedByString:@""];
#ifdef DEBUG
  NSLog(@"Running sheet with \"%@\"",phoneno);
#endif
  [sheet runSheetForPhone:phoneno];
  [sheet release];
}

- (void)dealloc
{
  [ABPane release];
  [super dealloc];
}
@end