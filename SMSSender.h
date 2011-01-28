//
//  SMSSender.h
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


#import <Cocoa/Cocoa.h>
#import "BluetoothCommandChannel.h"

@class BluetoothCommandChannel;
@class IOBluetoothDevice;
@class IOBluetoothSDPUUID;
@protocol SMSSenderDelegate;

#define kStateSentPDU -5
#define kStateSendingPDUs -4
#define kStateSendingBinaryFormat -3
#define kStateSendingATE0 -2
#define kStateSendingOpen -1
#define kStateBase 0
#define kStateTestingOpen 1
#define kStateTestingATE0 2
#define kStateTestingATCMGS 3

@interface SMSSender : NSObject <BluetoothCommandChannelDelegate> {
  BluetoothCommandChannel* channel;
  NSInteger testState;
  id<SMSSenderDelegate> delegate;
  NSMutableArray* pduQueue;
  NSString* currentPDU;
}

@property(assign) id<SMSSenderDelegate> delegate;

- (SMSSender*)initWithDevice:(IOBluetoothDevice*)device serviceUUID:(IOBluetoothSDPUUID*)uuid;
- (IOReturn)test;
- (IOReturn)sendSMS:(NSString*)smsText to:(NSString*)phoneNumber withReceipt:(BOOL)receipt;
+ (NSInteger)messageSize: (NSString*)text;
- (BOOL)reply:(NSString*)text toCommand:(NSString*)command;
- (void)workQueue;

@end

@protocol SMSSenderDelegate <NSObject>

- (void)testFailed:(NSString*)message;
- (void)testPassed;
- (void)sendFailed:(NSString*)message;
- (void)sendSucceeded;
- (void)statusUpdated:(NSString*)message;

@end