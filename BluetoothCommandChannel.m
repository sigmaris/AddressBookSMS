//
//  BluetoothCommandChannel.m
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


#import "BluetoothCommandChannel.h"
#import "BluetoothPhoneInfo.h"

@implementation BluetoothCommandChannel

@synthesize delegate;

- (BluetoothCommandChannel*)initWithDevice:(IOBluetoothDevice*)device serviceUUID:(IOBluetoothSDPUUID*)uuid
{
  self = [super init];
  if(self)
  {
#ifdef DEBUG
    NSString* currentUserHomeDirectory = NSHomeDirectory();
    NSLog(@"current home directory is %@",currentUserHomeDirectory);
    NSString* logfile = [currentUserHomeDirectory stringByAppendingPathComponent:@"ABSMSPlugin.log"];
    NSLog(@"logfile is %@",logfile);
    if(![[NSFileManager defaultManager] fileExistsAtPath:logfile])
    {
      [[NSFileManager defaultManager] createFileAtPath:logfile contents:nil attributes:nil];
    }
    log = [NSFileHandle fileHandleForWritingAtPath:logfile];
    [log seekToEndOfFile];
    [log retain];
#endif
    dev = [device retain];
    serviceUUID = [uuid retain];
    
    chan = nil;
    waitForReply = NO;
    command = nil;
    sendQueue = nil;
  }
  return self;
}

- (IOReturn)sendCommand:(NSString*)cmd
{
  IOReturn status;
  if ([self isReady])
  {
    NSUInteger MTU = [chan getMTU];
    command = [cmd retain];
    NSUInteger len = [cmd lengthOfBytesUsingEncoding: NSASCIIStringEncoding];
    NSRange usedRange = {0, [cmd length]};
    
    if((len + 1) > MTU)
    {
      //Length > MTU, msg must be split & queued
      NSRange leftover;
      NSUInteger usedBytes;
      
      //Queue up the split parts
      do
      {
        void* buffer = malloc(MTU);
        [cmd getBytes:buffer 
            maxLength:MTU
           usedLength:&usedBytes
             encoding:NSASCIIStringEncoding
              options:1
                range:usedRange
       remainingRange:&leftover];
        len = [[cmd substringWithRange:leftover] lengthOfBytesUsingEncoding:NSASCIIStringEncoding];
        NSData* dataObj = [NSData dataWithBytesNoCopy:buffer length:usedBytes];
        [sendQueue addObject:dataObj];
        usedRange = leftover;
      }
      while ((len + 1) > MTU);
      
      //queue up the last part and the newline
      char* buffer = malloc(len+1);
      [cmd getBytes:buffer 
          maxLength:len
         usedLength:&len
           encoding:NSASCIIStringEncoding
            options:1
              range:usedRange
     remainingRange:NULL];
      buffer[len] = '\r';
      NSData* dataObj = [NSData dataWithBytesNoCopy:buffer length:usedBytes];
      [sendQueue addObject:dataObj];
      status = [self workQueue];
    }
    else
    {
      char* buffer = malloc(len + 1);
      // write cmd into byte buffer
      [cmd getBytes:buffer maxLength:len usedLength:&len encoding:NSASCIIStringEncoding 
            options:1 range:usedRange remainingRange: NULL]; 
      buffer[len] = '\r';
      NSData* dataObj = [NSData dataWithBytesNoCopy:buffer length:(len+1)];
      // send through channel
#ifdef DEBUG
      [log writeData:[@"> " dataUsingEncoding:NSASCIIStringEncoding]];
      [log writeData:dataObj];
      [log writeData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
      NSLog(@"> %@",[[[NSString alloc] initWithData:dataObj encoding:NSASCIIStringEncoding] autorelease]);
#endif
#ifdef NOCOMM
      status = kIOReturnSuccess;
#else
      status = [chan writeAsync:buffer length:(len + 1) refcon:dataObj];
#endif
    }
  }
  else
  {
    status = kIOReturnIOError;
  }
  
  waitForReply = (status == kIOReturnSuccess);
  return status;
}

- (IOReturn)open
{
  IOReturn status;
  if(chan && [chan isOpen])
  {
    [self close];
  }
  IOBluetoothSDPServiceRecord* service = [dev getServiceRecordForUUID:serviceUUID];			
  if(service)
  {
    BluetoothRFCOMMChannelID channel_id;
    status = [service getRFCOMMChannelID: &channel_id];
    if(status == kIOReturnSuccess)
    {
      //NSLog(@"Opening service: %@ (channel: %d)", [service getServiceName], (int)channel_id);
      
      status = [dev openRFCOMMChannelAsync: &chan withChannelID:channel_id delegate:self];
      if(status == kIOReturnSuccess)
      {
        [chan retain];
      }
    }
  }
  else
  {
    status = kIOReturnNoDevice;
  }
  return status;
}

- (IOReturn)workQueue
{
  IOReturn status = kIOReturnSuccess;
  if([sendQueue count] > 0)
  {
    if(chan && [chan isOpen])
    {
      NSData* toSend = [sendQueue objectAtIndex:0];
      [toSend retain];
      [sendQueue removeObjectAtIndex:0];
      if([toSend length] > [chan getMTU])
        NSLog(@"WARNING: send %d longer than MTU %d",[toSend length],[chan getMTU]);
#ifdef DEBUG
      [log writeData:[@"> " dataUsingEncoding:NSASCIIStringEncoding]];
      [log writeData:toSend];
      [log writeData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
      NSLog(@"> %@",[[[NSString alloc] initWithData:toSend encoding:NSASCIIStringEncoding] autorelease]);
#endif
#ifdef NOCOMM
      status = kIOReturnSuccess;
#else
      status = [chan writeAsync:[toSend bytes] length:[toSend length] refcon:NULL];
#endif
      [toSend release];
    }
    else
    {
      status = kIOReturnIOError;
    }
  }
  return status;
}

- (void)close
{
  if(chan)
  {
    [chan closeChannel];
    [[chan getDevice] closeConnection];
    [chan autorelease];
    [chan setDelegate:nil];
    chan = nil;
  }
}

- (BOOL)isReady
{
  return (chan && [chan isOpen] && [chan getMTU] > 0 && !waitForReply && [sendQueue count] == 0);
}

- (BOOL)isOpen
{
  return (chan && [chan isOpen] && [chan getMTU] > 0);
}

+(NSArray*)listServices
{
  IOBluetoothSDPUUID* dunServiceUUID = [IOBluetoothSDPUUID uuid16:kBluetoothSDPUUID16ServiceClassDialupNetworking];
	IOBluetoothSDPUUID* serialServiceUUID = [IOBluetoothSDPUUID uuid16:kBluetoothSDPUUID16ServiceClassSerialPort];
	NSArray* devices = [IOBluetoothDevice pairedDevices];
  NSMutableArray* result = [NSMutableArray array];
  
	// enumerate through devices, taking those that support the needed profile.
	for(IOBluetoothDevice* dev in devices) {
		IOBluetoothSDPServiceRecord* dunService = [dev getServiceRecordForUUID: dunServiceUUID];
    IOBluetoothSDPServiceRecord* serialService = [dev getServiceRecordForUUID: serialServiceUUID];
		if(dunService)
    {
			BluetoothRFCOMMChannelID channelID;
			if([dunService getRFCOMMChannelID: &channelID] == kIOReturnSuccess)
      {
        BluetoothPhoneInfo* phone = [[BluetoothPhoneInfo alloc] init];
        phone.name = [NSString stringWithFormat:@"%@: %@",[dev getNameOrAddress],[dunService getServiceName]];
        phone.dev = dev;
        phone.uuid = dunServiceUUID;
        [result addObject:[phone autorelease]];
			}
		}
    if(serialService) 
    {
			BluetoothRFCOMMChannelID channelID;
			if([serialService getRFCOMMChannelID: &channelID] == kIOReturnSuccess)
      {
        BluetoothPhoneInfo* phone = [[BluetoothPhoneInfo alloc] init];
        phone.name = [NSString stringWithFormat:@"%@: %@",[dev getNameOrAddress],[serialService getServiceName]];
        phone.dev = dev;
        phone.uuid = serialServiceUUID;
        [result addObject:[phone autorelease]];
			}
		}
	}
	return result;
}


- (void)rfcommChannelData:(IOBluetoothRFCOMMChannel*)rfcommChannel data:(void *)dataPointer length:(size_t)dataLength
{
  NSString* fulltext = [[[NSString alloc] initWithBytes:dataPointer length:dataLength encoding:NSASCIIStringEncoding] autorelease];
#ifdef DEBUG
  NSLog(@"< %@",fulltext);
  [log writeData:[@"< " dataUsingEncoding:NSASCIIStringEncoding]];
  [log writeData:[fulltext dataUsingEncoding:NSASCIIStringEncoding]];
  [log writeData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
#endif
  NSArray* components = [fulltext componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
  for(NSString* text in components)
  {
    if(waitForReply)
    {
      if(command && [text hasPrefix:command])
      {
        //We got an echo, trim it off.
        text = [text substringFromIndex:[command length]];
      }
      text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if([text length] > 0)
      {
        NSString* oldCommand = command;
        waitForReply = NO;
        BOOL accepted = [delegate reply:text toCommand:command];
        if(accepted)
        {
          [oldCommand release];
        }
        else 
        {
          waitForReply = YES;
        }
      }
    }
    else if([text length] > 0)
    {
      NSLog(@"Unsolicited data: %@",text);
    }
  }
}

- (void)rfcommChannelOpenComplete:(IOBluetoothRFCOMMChannel*)rfcommChannel status:(IOReturn)error
{
  if(error == kIOReturnSuccess)
  {
		error = [rfcommChannel setSerialParameters:38400 dataBits:8 parity:kBluetoothRFCOMMParityTypeNoParity stopBits:1];
	}
  [delegate openComplete:error];
}

- (void)rfcommChannelWriteComplete:(IOBluetoothRFCOMMChannel*)rfcommChannel refcon:(void*)refcon status:(IOReturn)error
{
  if (!error && [sendQueue count] > 0)
  {
    [self workQueue];
  }
}

- (void)dealloc
{
  [self close];
  [dev release];
  [serviceUUID release];
#ifdef DEBUG
  [log closeFile];
  [log release];
#endif
  [super dealloc];
}
@end
