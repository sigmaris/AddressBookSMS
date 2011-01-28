//
//  BluetoothCommandChannel.h
//  bluetooth
//
//  Created by Hugh Cole-Baker on 20/09/2009.
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
#import <IOBluetooth/IOBluetooth.h>

@protocol BluetoothCommandChannelDelegate;

@interface BluetoothCommandChannel : NSObject {
  id<BluetoothCommandChannelDelegate> delegate;
  IOBluetoothRFCOMMChannel* chan;
  IOBluetoothDevice* dev;
	IOBluetoothSDPUUID* serviceUUID;
  
  BOOL waitForReply;
  NSString* command;
  NSMutableArray* sendQueue;
#ifdef DEBUG
  NSFileHandle* log;
#endif
}

@property(assign) id<BluetoothCommandChannelDelegate> delegate;

- (BluetoothCommandChannel*)initWithDevice:(IOBluetoothDevice*)device serviceUUID:(IOBluetoothSDPUUID*)uuid;
- (IOReturn)sendCommand:(NSString*)cmd;
- (IOReturn)open;
- (IOReturn)workQueue;
- (void)close;
- (BOOL)isReady;
- (BOOL)isOpen;

+(NSArray*)listServices;

- (void)rfcommChannelData:(IOBluetoothRFCOMMChannel*)rfcommChannel data:(void *)dataPointer length:(size_t)dataLength;
- (void)rfcommChannelOpenComplete:(IOBluetoothRFCOMMChannel*)rfcommChannel status:(IOReturn)error;
- (void)rfcommChannelWriteComplete:(IOBluetoothRFCOMMChannel*)rfcommChannel refcon:(void*)refcon status:(IOReturn)error;

@end

@protocol BluetoothCommandChannelDelegate <NSObject>

- (BOOL)reply:(NSString*)text toCommand:(NSString*)command;
- (void)openComplete:(IOReturn)status;

@end