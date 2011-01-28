//
//  SMSSender.mm
//  bluetooth
//
//  Created by Hugh Cole-Baker on 21/09/2009.
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


#import "SMSSender.h"
#import "BluetoothCommandChannel.h"
#import "BluetoothPhoneInfo.h"
#include "pdu.h"

@implementation SMSSender

@synthesize delegate;

- (SMSSender*)initWithDevice:(IOBluetoothDevice*)device serviceUUID:(IOBluetoothSDPUUID*)uuid
{
  self = [super init];
  if(self)
  {
    channel = [[BluetoothCommandChannel alloc] initWithDevice:device serviceUUID:uuid];
    channel.delegate = self;
    testState = kStateBase;
    pduQueue = [[NSMutableArray alloc] init];
  }
  return self;
}

+ (NSInteger)messageSize: (NSString*)text
{
	return countPDUs([text UTF8String]);
}

- (IOReturn)test
{
  IOReturn status = kIOReturnIOError;
  if([channel isOpen])
  {
    if([channel isReady])
    {
      testState = kStateTestingATE0;
      status = [channel sendCommand:@"ATE0"];
      if(status != kIOReturnSuccess)
      {
        testState = kStateBase;
      }
    }
  }
  else
  {
    testState = kStateTestingOpen;
    status = [channel open];
    if(status != kIOReturnSuccess)
    {
      testState = kStateBase;
    }
  }
  return status;
}

- (IOReturn)sendSMS:(NSString*)smsText to:(NSString*)phoneNumber withReceipt:(BOOL)receipt
{
  IOReturn status = kIOReturnLockedWrite;
  if(testState == kStateBase)
  {
    [pduQueue removeAllObjects];
    //queue up PDUs
    std::vector<std::string> pdus = buildPDUs("", [phoneNumber UTF8String], [smsText UTF8String], receipt);
    for(int k = 0; k < pdus.size(); ++k) 
    {
      NSString* pdu = [[NSString alloc] initWithUTF8String: pdus[k].c_str()];
      [pduQueue addObject:pdu];
      [pdu release];
    }
    if([channel isOpen])
    {
      if([channel isReady])
      {
        //set binary format
        testState = kStateSendingBinaryFormat;
        status = [channel sendCommand:@"AT+CMGF=0"];
        if(status != kIOReturnSuccess)
        {
          testState = kStateBase;
        }
      }
    }
    else
    {
      status = [channel open];
      if(status == kIOReturnSuccess)
      {
        testState = kStateSendingOpen;
      }
    }    
  }
  return status;
}

- (BOOL)reply:(NSString*)text toCommand:(NSString*)command
{
  BOOL accepted = YES;
  if(testState == kStateTestingATE0 && [command isEqualToString:@"ATE0"])
  {
    //Testing ATE0
    if([text isEqualToString:@"OK"])
    {
      testState = kStateTestingATCMGS;
      IOReturn status = [channel sendCommand:@"AT+CMGS=?"];
      if(status != kIOReturnSuccess)
      {
        [delegate testFailed:[NSString stringWithFormat:@"failed to send AT+CMGS=? with status %x",status]];
        testState = kStateBase;
      }
    }
    else
    {
      [delegate testFailed:[NSString stringWithFormat:@"got reply \"%@\" to ATE0 command",text]];
      testState = kStateBase;
    }
  }
  else if(testState == kStateSendingATE0 && [command isEqualToString:@"ATE0"])
  {
    //Sending ATE0
    if([text isEqualToString:@"OK"])
    {
      testState = kStateSendingBinaryFormat;
      IOReturn status = [channel sendCommand:@"AT+CMGF=0"];
      if(status != kIOReturnSuccess)
      {
        testState = kStateBase;
        [delegate sendFailed:@"could not send AT+CMGF=0"];
      }
    }
    else
    {
      [delegate sendFailed:[NSString stringWithFormat:@"got reply \"%@\" to ATE0 command",text]];
    }
  }
  else if(testState == kStateTestingATCMGS && [command isEqualToString:@"AT+CMGS=?"])
  {
    //Testing AT+CMGS
    if([text isEqualToString:@"OK"])
    {
      [delegate testPassed];
    }
    else if([text rangeOfString:@"OK"].location != NSNotFound)
    {
      [delegate testPassed];
    }
    else
    {
      [delegate testFailed:[NSString stringWithFormat:@"got reply \"%@\" to AT+CMGS=? command",text]];
    }
    testState = kStateBase;
  }
  else if((testState == kStateSentPDU) || (testState == kStateSendingBinaryFormat && [command isEqualToString:@"AT+CMGF=0"]))
  {
    if([text isEqualToString:@"+CMGF: 0"] || [text hasPrefix:@"+CMGS:"])
    {
      accepted = NO;
    }
    //Send the next PDU
    else if([text isEqualToString:@"OK"])
    {
      if([pduQueue count] > 0)
      {
        testState = kStateSendingPDUs;
        [delegate statusUpdated:[NSString stringWithFormat:@"sending %d messages...", [pduQueue count]]];
        [self workQueue];
      }
      else
      {
        testState = kStateBase;
        [delegate sendSucceeded];
      }
    }
    else
    {
      [delegate sendFailed:[NSString stringWithFormat:@"got reply \"%@\" to send command",text]];
      testState = kStateBase;
    }
  }
  else if(testState == kStateSendingPDUs && [command hasPrefix:@"AT+CMGS="])
  {
    //send payload
    testState = kStateSentPDU;
    IOReturn status = [channel sendCommand:[NSString stringWithFormat:@"%@\x1a", currentPDU]];
    if(status != kIOReturnSuccess)
    {
      testState = kStateBase;
      [delegate sendFailed:@"could not send PDU payload"];
    }
    [currentPDU release];
    currentPDU = nil;
  }
  else
  {
    //general error
    if(testState > kStateBase)
    {
      [delegate testFailed:[NSString stringWithFormat:@"received %@ as reply to %@ in state %d", text, command, testState]];
      testState = kStateBase;
    }
    else
    {
      [delegate sendFailed:[NSString stringWithFormat:@"received %@ as reply to %@ in state %d", text, command, testState]];
      testState = kStateBase;
    }
  }
  return accepted;
}

- (void)workQueue
{
  if([pduQueue count] > 0)
  {
    if([channel isReady])
    {
      if(currentPDU)
      {
        [currentPDU release];
      }
      currentPDU = [pduQueue objectAtIndex:0];
      [currentPDU retain];
      [pduQueue removeObjectAtIndex:0];
      IOReturn status = [channel sendCommand:[NSString stringWithFormat:@"AT+CMGS=%d",[currentPDU length] / 2 - 1]];
      if(status != kIOReturnSuccess)
      {
        [currentPDU release];
        currentPDU = nil;
        [delegate sendFailed:@"failed to send AT+CMGS= for next PDU"];
      }
    }
    else
    {
      [delegate sendFailed:@"channel is not ready to send AT+CMGS="];
    }
  }
  
}

- (void)openComplete:(IOReturn)status
{
  if(status == kIOReturnSuccess && testState == kStateTestingOpen)
  {
    //We are opening for testing
    if([channel isReady])
    {
      testState = kStateTestingATE0;
      status = [channel sendCommand:@"ATE0"];
      if(status != kIOReturnSuccess)
      {
        [delegate testFailed:@"failed to send ATE0"];
        testState = kStateBase;
      }
    }
    else
    {
      [delegate testFailed:@"channel opened but not ready"];
      testState = kStateBase;
    }
  }
  else if(status == kIOReturnSuccess && testState == kStateSendingOpen)
  {
    //we are opening to send
    if([channel isReady])
    {
      testState = kStateSendingATE0;
      status = [channel sendCommand:@"ATE0"];
      if(status != kIOReturnSuccess)
      {
        [delegate sendFailed:@"failed to send ATE0"];
        testState = kStateBase;
      }
    }
    else
    {
      [delegate sendFailed:@"channel opened but not ready"];
      testState = kStateBase;
    }
  }
  else
  {
    if(testState > kStateBase)
    {
      [delegate testFailed:@"failed to open channel"];
    }
    else
    {
      [delegate sendFailed:@"failed to open channel"];
    }
    testState = kStateBase;
  }
}

- (void)dealloc
{
  [channel release];
  [pduQueue release];
  [super dealloc];
}

@end
