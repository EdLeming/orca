//--------------------------------------------------------
// ORAmi286Model
// Created by Mark  A. Howe on Mon Aug 27 2007
// Code partially generated by the OrcaCodeWizard. Written by Mark A. Howe.
// Copyright (c) 2005 CENPA, University of Washington. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of 
//Washington at the Center for Experimental Nuclear Physics and 
//Astrophysics (CENPA) sponsored in part by the United States 
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020. 
//The University has certain rights in the program pursuant to 
//the contract and the program should not be copied or distributed 
//outside your organization.  The DOE and the University of 
//Washington reserve all rights in the program. Neither the authors,
//University of Washington, or U.S. Government make any warranty, 
//express or implied, or assume any liability or responsibility 
//for the use of this software.
//-------------------------------------------------------------

#pragma mark •••Imported Files

#import "ORAmi286Model.h"
#import "ORSerialPort.h"
#import "ORSerialPortList.h"
#import "ORSerialPort.h"
#import "ORSerialPortAdditions.h"
#import "ORDataTypeAssigner.h"
#import "ORDataPacket.h"
#import "ORTimeRate.h"
#import "ORMailer.h"

#pragma mark •••External Strings
NSString* ORAmi286ModelSendOnAlarmChanged		= @"ORAmi286ModelSendOnAlarmChanged";
NSString* ORAmi286ModelExpiredTimeChanged		= @"ORAmi286ModelExpiredTimeChanged";
NSString* ORAmi286ModelSendOnExpiredChanged		= @"ORAmi286ModelSendOnExpiredChanged";
NSString* ORAmi286ModelSendOnValveChangeChanged = @"ORAmi286ModelSendOnValveChangeChanged";
NSString* ORAmi286ModelEnabledMaskChanged		= @"ORAmi286ModelEnabledMaskChanged";
NSString* ORAmi286ModelShipLevelsChanged		= @"ORAmi286ModelShipLevelsChanged";
NSString* ORAmi286ModelPollTimeChanged			= @"ORAmi286ModelPollTimeChanged";
NSString* ORAmi286ModelSerialPortChanged		= @"ORAmi286ModelSerialPortChanged";
NSString* ORAmi286ModelPortNameChanged			= @"ORAmi286ModelPortNameChanged";
NSString* ORAmi286ModelPortStateChanged			= @"ORAmi286ModelPortStateChanged";
NSString* ORAmi286FillStateChanged				= @"ORAmi286FillStateChanged";
NSString* ORAmi286AlarmLevelChanged				= @"ORAmi286AlarmLevelChanged";
NSString* ORAmi286Update						= @"ORAmi286Update";
NSString* ORAmi286EMailEnabledChanged			= @"ORAmi286EMailEnabledChanged";
NSString* ORAmi286EMailAddressesChanged			= @"ORAmi286EMailAddressesChanged";
NSString* ORAmi286LastChange					= @"ORAmi286LastChange";
NSString* ORAmi286FillPointChanged				= @"ORAmi286FillPointChanged";

NSString* ORAmi286Lock = @"ORAmi286Lock";

#define kAmi286EMailDelay 60

@interface ORAmi286Model (private)
- (void) runStarted:(NSNotification*)aNote;
- (void) runStopped:(NSNotification*)aNote;
- (void) timeout;
- (void) processOneCommandFromQueue;
- (void) process_response:(NSString*)theResponse;
- (void) sendEMails;
- (void) eMailThread;
- (void) scheduleStatusSend;
- (void) startExpiredTimer:(int)i;
- (void) stopExpiredTimer:(int)i;
- (void) addReason:(NSString*) aReason;
- (void) clearReasons;
@end

@implementation ORAmi286Model
- (id) init
{
	self = [super init];
    [self registerNotificationObservers];
	eMailLock = [[NSLock alloc] init];
	ignoreSend = YES;
	sendIsScheduled = NO;
	return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [buffer release];
	[cmdQueue release];
	[lastRequest release];
    [portName release];
    if([serialPort isOpen]){
        [serialPort close];
    }
    [serialPort release];
	int i;
	for(i=0;i<4;i++){
		[timeRates[i] release];
		[lastChange[i] release];
		[self stopExpiredTimer:i];
		[hiAlarm[i] clearAlarm];
		[hiAlarm[i] release];
		
		[lowAlarm[i] clearAlarm];
		[lowAlarm[i] release];	
		[expiredAlarm[i] clearAlarm];
		[expiredAlarm[i] release];
	}
	

	[self clearReasons];
	
	[eMailLock release];
	[eMailList release];
	[super dealloc];
}

- (void) sleep
{
	[super sleep];
	int i;
	for(i=0;i<4;i++){
		[self stopExpiredTimer:i];
	}
}

- (void) wakeUp
{
	[super wakeUp];
	if(sendOnExpired){
		int i;
		for(i=0;i<4;i++){
			[self startExpiredTimer:i];		
		}		
	}
}

- (void) setUpImage
{
	[self setImage:[NSImage imageNamed:@"Ami286.tif"]];
}

- (void) makeMainController
{
	[self linkToController:@"ORAmi286Controller"];
}

- (NSString*) helpURL
{
	return @"RS232/Ami286.html";
}

- (void) registerNotificationObservers
{
	NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
	
    [notifyCenter addObserver : self
                     selector : @selector(dataReceived:)
                         name : ORSerialPortDataReceived
                       object : nil];
	
    [notifyCenter addObserver: self
                     selector: @selector(runStarted:)
                         name: ORRunStartedNotification
                       object: nil];
    
    [notifyCenter addObserver: self
                     selector: @selector(runStopped:)
                         name: ORRunStoppedNotification
                       object: nil];
	
}

- (void) dataReceived:(NSNotification*)note
{
    if([[note userInfo] objectForKey:@"serialPort"] == serialPort){
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeout) object:nil];
        NSString* theString = [[[[NSString alloc] initWithData:[[note userInfo] objectForKey:@"data"] 
												      encoding:NSASCIIStringEncoding] autorelease] uppercaseString];
		
		//the serial port may break the data up into small chunks, so we have to accumulate the chunks until
		//we get a full piece.
        theString = [[theString componentsSeparatedByString:@"\n"] componentsJoinedByString:@""];
        if(!buffer)buffer = [[NSMutableString string] retain];
        [buffer appendString:theString];					
		
        do {
            NSRange lineRange = [buffer rangeOfString:@"\r"];
            if(lineRange.location!= NSNotFound){
                NSMutableString* theResponse = [[[buffer substringToIndex:lineRange.location+1] mutableCopy] autorelease];
                [buffer deleteCharactersInRange:NSMakeRange(0,lineRange.location+1)];      //take the cmd out of the buffer
				
				[self process_response:theResponse];
				
				[self setLastRequest:nil];			 //clear the last request
				[self processOneCommandFromQueue];	 //do the next command in the queue
            }
        } while([buffer rangeOfString:@"\r"].location!= NSNotFound);
	}
}


- (void) shipLevelValues
{
    if([[ORGlobal sharedGlobal] runInProgress]){
		
		unsigned long data[10];
		data[0] = dataId | 10;
		data[1] = [self uniqueIdNumber]&0xfff;
		
		union {
			float asFloat;
			unsigned long asLong;
		}theData;
		int index = 2;
		int i;
		for(i=0;i<4;i++){
			
			data[1] |= ([self fillState:i] & 0xf) << (16 + (i*4));
			
			theData.asFloat = level[i];
			data[index] = theData.asLong;
			index++;
			
			data[index] = timeMeasured[i];
			index++;
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:ORQueueRecordForShippingNotification 
															object:[NSData dataWithBytes:data length:sizeof(long)*10]];
	}
}

#pragma mark •••Accessors

- (BOOL) sendOnAlarm
{
    return sendOnAlarm;
}

- (void) setSendOnAlarm:(BOOL)aSendOnAlarm
{
    [[[self undoManager] prepareWithInvocationTarget:self] setSendOnAlarm:sendOnAlarm];
    
    sendOnAlarm = aSendOnAlarm;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelSendOnAlarmChanged object:self];
}

- (long) expiredTime
{
    return expiredTime;
}

- (void) setExpiredTime:(long)aExpiredTime
{
    [[[self undoManager] prepareWithInvocationTarget:self] setExpiredTime:expiredTime];
    if(aExpiredTime<1)aExpiredTime = 1;
    expiredTime = aExpiredTime;

	int i;
	for(i=0;i<4;i++){
		[self startExpiredTimer:i];		
	}		
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelExpiredTimeChanged object:self];
}

- (BOOL) sendOnExpired
{
    return sendOnExpired;
}

- (void) setSendOnExpired:(BOOL)aSendOnExpired
{
    [[[self undoManager] prepareWithInvocationTarget:self] setSendOnExpired:sendOnExpired];
    
    sendOnExpired = aSendOnExpired;

	if(sendOnExpired){
		int i;
		for(i=0;i<4;i++){
			[self startExpiredTimer:i];
		}
	}
	else {
		int i;
		for(i=0;i<4;i++){
			[self stopExpiredTimer:i];
		}
	}
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelSendOnExpiredChanged object:self];
}

- (BOOL) sendOnValveChange
{
    return sendOnValveChange;
}

- (void) setSendOnValveChange:(BOOL)aSendOnValveChange
{
    [[[self undoManager] prepareWithInvocationTarget:self] setSendOnValveChange:sendOnValveChange];
    
    sendOnValveChange = aSendOnValveChange;

    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelSendOnValveChangeChanged object:self];
}

- (BOOL) emailEnabled
{
    return emailEnabled;
}

- (void) setEmailEnabled:(BOOL)aEmailEnabled
{
    [[[[NSApp delegate] undoManager] prepareWithInvocationTarget:self] setEmailEnabled:emailEnabled];
    emailEnabled = aEmailEnabled;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scheduleStatusSend) object:nil];
	if(emailEnabled){
		if(sendOnExpired){
			int i;
			for(i=0;i<4;i++){
				[self startExpiredTimer:i];
			}
		}
	}
	else {
		int i;
		for(i=0;i<4;i++){
			[self stopExpiredTimer:i];
		}
		[self clearReasons];
	}
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286EMailEnabledChanged object:self];
}

- (NSMutableArray*) eMailList
{
    return eMailList;
}

- (void) setEMailList:(NSMutableArray*)aEMailList
{
    [aEMailList retain];
    [eMailList release];
    eMailList = aEMailList;
}

- (void) addEMail
{
	if(!eMailList)[self setEMailList:[NSMutableArray array]];
	[eMailList addObject:@"eMail Address"];
}

- (void) removeEMail:(unsigned) anIndex
{
	[eMailList removeObjectAtIndex:anIndex];
}

- (NSString*) addressAtIndex:(unsigned)anIndex
{
	if(anIndex>=0 && anIndex<[eMailList count])return [eMailList objectAtIndex:anIndex];
	else return nil;
}

- (unsigned char) enabledMask
{
    return enabledMask;
}

- (void) setEnabledMask:(unsigned char)anEnabledMask
{
    [[[self undoManager] prepareWithInvocationTarget:self] setEnabledMask:enabledMask];
    
    enabledMask = anEnabledMask;
	
	[[self undoManager] disableUndoRegistration];
	[self setEmailEnabled:emailEnabled];
	[[self undoManager] enableUndoRegistration];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelEnabledMaskChanged object:self];
}

- (ORTimeRate*)timeRate:(int)index
{
	return timeRates[index];
}

- (BOOL) shipLevels
{
    return shipLevels;
}

- (void) setShipLevels:(BOOL)aShipLevels
{
    [[[self undoManager] prepareWithInvocationTarget:self] setShipLevels:shipLevels];
    
    shipLevels = aShipLevels;
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelShipLevelsChanged object:self];
}

- (int) pollTime
{
    return pollTime;
}

- (void) setPollTime:(int)aPollTime
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPollTime:pollTime];
    pollTime = aPollTime;
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelPollTimeChanged object:self];
	
	if(pollTime){
		[self performSelector:@selector(pollLevels) withObject:nil afterDelay:2];
	}
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pollLevels) object:nil];
	}
}

- (void) pollLevels
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pollLevels) object:nil];
	[self readLevels];
	
	[self performSelector:@selector(pollLevels) withObject:nil afterDelay:pollTime];
}
- (unsigned long) timeMeasured:(int)index
{
	if(index>=0 && index<4 && (enabledMask&(1<<index)))return timeMeasured[index];
	else return 0;
}

- (int) fillStatus:(int)index
{
	if(index>=0 && index<4)return fillStatus[index];
	else return 0;
}

- (void) setFillStatus:(int)index value:(int)aValue;
{
	if(index>=0 && index<4){

		if(fillStatus[index]!=aValue){
			[self setLastChange:index];
			if(sendOnValveChange){
				NSString* time = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%m/%d %I:%M %p"];
				[self addReason:[NSString stringWithFormat:@"Chan %d. Fill State Changed to %@ at %@\n",index,[self fillStatusName:aValue], time]];
				[self scheduleStatusSend];
			}
			if(sendOnExpired)[self startExpiredTimer:index];
			NSLog(@"<%@>: Chan %d. Fill State Changed to %@\n",[self fullID], index,[self fillStatusName:aValue]);
		}
		
		fillStatus[index] = aValue;
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
		[[NSNotificationCenter defaultCenter] postNotificationName: ORAmi286Update
															object:self 
														  userInfo:userInfo];
	}
}

- (NSDate*) lastChange:(int)index
{
	if(index>=0 && index<4)return lastChange[index];
	else return 0;
}

- (void) setLastChange:(int)index;
{
	if(index>=0 && index<4){
		
		[lastChange[index] release];
		lastChange[index] = [[NSCalendarDate date] retain];
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
		[[NSNotificationCenter defaultCenter] postNotificationName: ORAmi286LastChange
															object:self 
														  userInfo:userInfo];
	}
}


- (int) alarmStatus:(int)index
{
	if(index>=0 && index<4)return alarmStatus[index];
	else return 0;
}

- (void) setAlarmStatus:(int)index value:(int)aValue;
{
	if(index>=0 && index<4){
		alarmStatus[index] = aValue;
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
		[[NSNotificationCenter defaultCenter] postNotificationName: ORAmi286Update
															object:self 
														  userInfo:userInfo];
		
		if(alarmStatus[index] & (1<<0)){
			if(!hiAlarm[index]){
				hiAlarm[index] = [[ORAlarm alloc] initWithName:@"Ami 286 Hi Level" severity:kRangeAlarm];
				[hiAlarm[index] setSticky:YES];
			}
			[hiAlarm[index] postAlarm];
			if(sendOnAlarm){
				NSString* time = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%m/%d %I:%M %p"];
				[self addReason:[NSString stringWithFormat:@"Chan %d. Hi Alarm posted at %@\n",index,time]];
				[self scheduleStatusSend];
			}
		}
		else {
			[hiAlarm[index] clearAlarm];
			[hiAlarm[index] release];
			hiAlarm[index] = nil;
		}
		if(alarmStatus[index] & (1<<3)){
			if(!lowAlarm[index]){
				lowAlarm[index] = [[ORAlarm alloc] initWithName:@"Ami 286 Low Level" severity:kRangeAlarm];
				[lowAlarm[index] setSticky:YES];
			}
			[lowAlarm[index] postAlarm];
			if(sendOnAlarm){
				NSString* time = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%m/%d %I:%M %p"];
				[self addReason:[NSString stringWithFormat:@"Chan %d. Low Alarm posted at %@\n",index,time]];
				[self scheduleStatusSend];
			}
		}
		else {
			[lowAlarm[index] clearAlarm];
			[lowAlarm[index] release];
			lowAlarm[index] = nil;
		}
		if(alarmStatus[index] & (1<<6)){
			if(!expiredAlarm[index]){
				expiredAlarm[index] = [[ORAlarm alloc] initWithName:@"Ami 286 Expired" severity:kRangeAlarm];
				[expiredAlarm[index] setSticky:YES];
			}
			[expiredAlarm[index] postAlarm];
			if(sendOnAlarm){
				NSString* time = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%m/%d %I:%M %p"];
				[self addReason:[NSString stringWithFormat:@"Chan %d. Expired Alarm posted at %@\n",index,time]];
				[self scheduleStatusSend];
			}
		}
		else {
			[expiredAlarm[index] clearAlarm];
			[expiredAlarm[index] release];
			expiredAlarm[index] = nil;
		}
	}
}

- (int) fillState:(int)index
{
	if(index>=0 && index<4)return fillState[index];
	else return 0;
}

- (void) setFillState:(int)index value:(int)aValue;
{
	if(index>=0 && index<4){
		[[[self undoManager] prepareWithInvocationTarget:self] setFillState:index value:fillState[index]];
				
		fillState[index] = aValue;
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
		[[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286FillStateChanged 
															object:self 
														  userInfo:userInfo];
	}
}

- (NSString*) fillStatusName:(int)i
{
	switch(i){
		case 0: return @"Off";
		case 1: return @"On";
		case 2: return @"Auto-Off";
		case 3: return @"Auto-On";
		case 4: return @"Expired";
		default: return @"?";
	}
}

- (NSString*) fillStateName:(int)i
{
	switch(i){
		case 0: return @"Off";
		case 1: return @"On";
		case 2: return @"Auto";
		default: return @"?";
	}
}

- (float) level:(int)index
{
	
	if(index>=0 && index<4 && (enabledMask&(1<<index)))return level[index];
	else return 0.0;
}

- (void) setLevel:(int)index value:(float)aValue;
{
	if(index>=0 && index<4){
		level[index] = aValue;
		//get the time(UT!)
		time_t	ut_Time;
		time(&ut_Time);
		//struct tm* theTimeGMTAsStruct = gmtime(&theTime);
		timeMeasured[index] = ut_Time;
		
		NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
		[[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286Update 
															object:self 
														  userInfo:userInfo];
		
		if(timeRates[index] == nil) timeRates[index] = [[ORTimeRate alloc] init];
		[timeRates[index] addDataToTimeAverage:aValue];
	}
}

- (void) setLowAlarmLevel:(int)index value:(float)aValue
{
	if(aValue<0)aValue = 0;
	else if(aValue>100)aValue=100;
    [[[self undoManager] prepareWithInvocationTarget:self] setLowAlarmLevel:index value:lowAlarmLevel[index]];
	
	lowAlarmLevel[index] = aValue;
	if(lowAlarmLevel[index] >= hiAlarmLevel[index])[self setHiAlarmLevel:index value:lowAlarmLevel[index]];
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286AlarmLevelChanged object:self userInfo:userInfo];
	
}

- (float) lowAlarmLevel:(int)index
{
	if(index>=0 && index<=10)return lowAlarmLevel[index];
	else return 0;
}

- (void) setHiAlarmLevel:(int)index value:(float)aValue
{
	if(aValue<0)aValue = 0;
	else if(aValue>100)aValue=100;
	
    [[[self undoManager] prepareWithInvocationTarget:self] setHiAlarmLevel:index value:hiAlarmLevel[index]];
	
	hiAlarmLevel[index] = aValue;
	if(hiAlarmLevel[index] < lowAlarmLevel[index])[self setLowAlarmLevel:index value:hiAlarmLevel[index]];
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286AlarmLevelChanged object:self userInfo:userInfo];
	
}

- (float) hiAlarmLevel:(int)index
{
	if(index>=0 && index<=10)return hiAlarmLevel[index];
	else return 0;
}

- (void) setLowFillPoint:(int)index value:(float)aValue
{
	if(aValue<0)aValue = 0;
	else if(aValue>100)aValue=100;
    [[[self undoManager] prepareWithInvocationTarget:self] setLowFillPoint:index value:lowFillPoint[index]];
	
	lowFillPoint[index] = aValue;
	if(lowFillPoint[index] >= hiFillPoint[index])[self setHiFillPoint:index value:lowFillPoint[index]];
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286FillPointChanged object:self userInfo:userInfo];
	
}

- (float) lowFillPoint:(int)index
{
	if(index>=0 && index<=10)return lowFillPoint[index];
	else return 0;
}

- (void) setHiFillPoint:(int)index value:(float)aValue
{
	if(aValue<0)aValue = 0;
	else if(aValue>100)aValue=100;
	
    [[[self undoManager] prepareWithInvocationTarget:self] setHiFillPoint:index value:hiFillPoint[index]];
	
	hiFillPoint[index] = aValue;
	if(hiFillPoint[index] < lowFillPoint[index])[self setLowFillPoint:index value:hiFillPoint[index]];
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:index] forKey:@"Index"];
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286FillPointChanged object:self userInfo:userInfo];
	
}

- (float) hiFillPoint:(int)index
{
	if(index>=0 && index<=10)return hiFillPoint[index];
	else return 0;
}

- (NSString*) lastRequest
{
	return lastRequest;
}

- (void) setLastRequest:(NSString*)aRequest
{
	[lastRequest autorelease];
	lastRequest = [aRequest copy];    
}

- (BOOL) portWasOpen
{
    return portWasOpen;
}

- (void) setPortWasOpen:(BOOL)aPortWasOpen
{
    portWasOpen = aPortWasOpen;
}

- (NSString*) portName
{
    return portName;
}

- (void) setPortName:(NSString*)aPortName
{
    [[[self undoManager] prepareWithInvocationTarget:self] setPortName:portName];
    
    if(![aPortName isEqualToString:portName]){
        [portName autorelease];
        portName = [aPortName copy];    
		
        BOOL valid = NO;
        NSEnumerator *enumerator = [ORSerialPortList portEnumerator];
        ORSerialPort *aPort;
        while (aPort = [enumerator nextObject]) {
            if([portName isEqualToString:[aPort name]]){
                [self setSerialPort:aPort];
                if(portWasOpen){
                    [self openPort:YES];
				}
                valid = YES;
                break;
            }
        } 
        if(!valid){
            [self setSerialPort:nil];
        }       
    }
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelPortNameChanged object:self];
}

- (ORSerialPort*) serialPort
{
    return serialPort;
}

- (void) setSerialPort:(ORSerialPort*)aSerialPort
{
    [aSerialPort retain];
    [serialPort release];
    serialPort = aSerialPort;
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelSerialPortChanged object:self];
}

- (void) openPort:(BOOL)state
{
    if(state) {
		[serialPort setSpeed:9600];
		[serialPort setParityOdd];
		[serialPort setStopBits2:1];
		[serialPort setDataBits:7];
        [serialPort open];
    }
    else      [serialPort close];
    portWasOpen = [serialPort isOpen];
	
	[[self undoManager] disableUndoRegistration];
	[self setEmailEnabled:emailEnabled];
	[[self undoManager] enableUndoRegistration];
	
    [[NSNotificationCenter defaultCenter] postNotificationName:ORAmi286ModelPortStateChanged object:self];
}


#pragma mark •••Archival
- (id) initWithCoder:(NSCoder*)decoder
{
	self = [super initWithCoder:decoder];
	[[self undoManager] disableUndoRegistration];
	[self setSendOnAlarm:[decoder decodeBoolForKey:@"sendOnAlarm"]];
	[self setExpiredTime:[decoder decodeInt32ForKey:@"expiredTime"]];
	[self setSendOnExpired:[decoder decodeBoolForKey:@"sendOnExpired"]];
	[self setSendOnValveChange:[decoder decodeBoolForKey:@"sendOnValveChange"]];
	[self setEnabledMask:[decoder decodeIntForKey:@"enabledMask"]];
	[self setShipLevels:[decoder decodeBoolForKey:@"ORAmi286ModelShipLevels"]];
	[self setPollTime:[decoder decodeIntForKey:@"ORAmi286ModelPollTime"]];
	[self setPortWasOpen:[decoder decodeBoolForKey:@"ORAmi286ModelPortWasOpen"]];
    [self setPortName:[decoder decodeObjectForKey: @"portName"]];
    [self setEMailList:[decoder decodeObjectForKey: @"eMailList"]];
    [self setEmailEnabled:[decoder decodeBoolForKey: @"emailEnabled"]];
	
	if(expiredTime == 0)[self setExpiredTime:60];
	
	if(!eMailList)[self setEMailList:[NSMutableArray array]];
	
	int i;
	for(i=0;i<4;i++){
		timeRates[i] = [[ORTimeRate alloc] init];
		[self setLowAlarmLevel:i value:[decoder decodeFloatForKey:[NSString stringWithFormat:@"LowAlarm%d",i]]];
		[self setHiAlarmLevel:i value:[decoder decodeFloatForKey:[NSString stringWithFormat:@"HiAlarm%d",i]]];
		[self setLowFillPoint:i value:[decoder decodeFloatForKey:[NSString stringWithFormat:@"lowFillPoint%d",i]]];
		[self setHiFillPoint:i value:[decoder decodeFloatForKey:[NSString stringWithFormat:@"hiFillPoint%d",i]]];
		[self setFillState:i value:[decoder decodeIntForKey:[NSString stringWithFormat:@"FillState%d",i]]];
		[self setLastChange:i];
	}
    [self registerNotificationObservers];
	eMailLock = [[NSLock alloc] init];
	ignoreSend = NO;
	sendIsScheduled = NO;
	[[self undoManager] enableUndoRegistration];

	return self;
}

- (void) encodeWithCoder:(NSCoder*)encoder
{
    [super encodeWithCoder:encoder];
    [encoder encodeBool:sendOnAlarm forKey:@"sendOnAlarm"];
    [encoder encodeInt32:expiredTime forKey:@"expiredTime"];
    [encoder encodeBool:sendOnExpired forKey:@"sendOnExpired"];
    [encoder encodeBool:sendOnValveChange forKey:@"sendOnValveChange"];
    [encoder encodeInt:enabledMask forKey:@"enabledMask"];
    [encoder encodeBool:shipLevels forKey:@"ORAmi286ModelShipLevels"];
    [encoder encodeInt:pollTime forKey:@"ORAmi286ModelPollTime"];
    [encoder encodeBool:portWasOpen forKey:@"ORAmi286ModelPortWasOpen"];
    [encoder encodeObject:portName forKey: @"portName"];
    [encoder encodeObject:eMailList forKey: @"eMailList"];
    [encoder encodeBool:emailEnabled forKey: @"emailEnabled"];
	int i;
	for(i=0;i<4;i++){
		[encoder encodeFloat:lowAlarmLevel[i] forKey:[NSString stringWithFormat:@"LowAlarm%d",i]];
		[encoder encodeFloat:hiAlarmLevel[i] forKey:[NSString stringWithFormat:@"HiAlarm%d",i]];
		[encoder encodeFloat:lowFillPoint[i] forKey:[NSString stringWithFormat:@"lowFillPoint%d",i]];
		[encoder encodeFloat:hiFillPoint[i] forKey:[NSString stringWithFormat:@"hiFillPoint%d",i]];
		[encoder encodeInt:fillState[i] forKey:[NSString stringWithFormat:@"FillState%d",i]];
	}
}

#pragma mark ••• Commands
- (void) loadHardware
{
	int i;
	for(i=0;i<2;i++){
		if(enabledMask&(1<<i)){
			[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:Fill:State %d",i+1,fillState[i]]];
			[self addCmdToQueue:@"*OPC?"];
		}
	}
	[self loadAlarmsToHardware];
	[self loadFillPointsToHardware];
	[self readLevels];
}

- (void) loadFillState
{
	int i;
	for(i=0;i<2;i++){
		if(i<2){
			[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:Fill:State %d",i+1,fillState[i]]];
		}
	}
}


- (void) addCmdToQueue:(NSString*)aCmd
{
    if([serialPort isOpen]){ 
		if(!cmdQueue)cmdQueue = [[NSMutableArray array] retain];
		[cmdQueue addObject:aCmd];
		if(!lastRequest){
			[self processOneCommandFromQueue];
		}
	}
}

- (void) readLevels
{
	[self readLevels:YES];
}

- (void) readLevels:(BOOL)ship
{
	if(!unitsSet){
		[self addCmdToQueue:@"PERC"]; //default to percent units
		unitsSet = YES;
	}
	int i;
	for(i=0;i<4;i++){
		if(enabledMask&(1<<i)){
			[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:LEV?",i+1]];
			[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:STATUS:ALARM:CONDITION?",i+1]];
			if(i<2)[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:FILL:STATE?",i+1]];
		}
	}
	[self addCmdToQueue:@"++ShipRecords"];
}

- (void) loadAlarmsToHardware
{
	int i;
	for(i=0;i<4;i++){
		if(enabledMask&(1<<i)){
			[self setLowAlarm:i withValue:lowAlarmLevel[i]];
			[self setHighAlarm:i withValue:hiAlarmLevel[i]];
		}
	}
}

- (void) loadFillPointsToHardware
{
	int i;
	for(i=0;i<4;i++){
		if(enabledMask&(1<<i)){
			[self setLowFillPoint:i withValue:lowFillPoint[i]];
			[self setHighFillPoint:i withValue:hiFillPoint[i]];
		}
	}
}

- (void) setLowAlarm:(int)chan withValue:(float)aValue
{
	if(!unitsSet){
		[self addCmdToQueue:@"PERC"]; //default to percent units
		unitsSet = YES;
	}
	[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:ALAR:LO %.1f",chan+1,aValue]];
	[self addCmdToQueue:@"*OPC?"];
}

- (void) setHighAlarm:(int)chan withValue:(float)aValue
{
	if(!unitsSet){
		[self addCmdToQueue:@"PERC"]; //default to percent units
		unitsSet = YES;
	}
	[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:ALAR:HI %.1f",chan+1,aValue]];
	[self addCmdToQueue:@"*OPC?"];
}

- (void) setLowFillPoint:(int)chan withValue:(float)aValue
{
	if(chan>1)return;
	if(!unitsSet){
		[self addCmdToQueue:@"PERC"]; //default to percent units
		unitsSet = YES;
	}
	[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:ALAR:B %.1f",chan+1,aValue]];
	[self addCmdToQueue:@"*OPC?"];
}

- (void) setHighFillPoint:(int)chan withValue:(float)aValue
{
	if(chan>1)return;
	if(!unitsSet){
		[self addCmdToQueue:@"PERC"]; //default to percent units
		unitsSet = YES;
	}
	[self addCmdToQueue:[NSString stringWithFormat:@"CH%d:ALAR:A %.1f",chan+1,aValue]];
	[self addCmdToQueue:@"*OPC?"];
}


#pragma mark •••Data Records
- (unsigned long) dataId { return dataId; }
- (void) setDataId: (unsigned long) DataId
{
    dataId = DataId;
}
- (void) setDataIds:(id)assigner
{
    dataId       = [assigner assignDataIds:kLongForm];
}

- (void) syncDataIdsWith:(id)anotherAmi286
{
    [self setDataId:[anotherAmi286 dataId]];
}

- (void) appendDataDescription:(ORDataPacket*)aDataPacket userInfo:(id)userInfo
{
    //----------------------------------------------------------------------------------------
    // first add our description to the data description
    [aDataPacket addDataDescriptionItem:[self dataRecordDescription] forKey:@"Ami286Model"];
}

- (NSDictionary*) dataRecordDescription
{
    NSMutableDictionary* dataDictionary = [NSMutableDictionary dictionary];
    NSDictionary* aDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"ORAmi286DecoderForLevel",     @"decoder",
								 [NSNumber numberWithLong:dataId],   @"dataId",
								 [NSNumber numberWithBool:NO],       @"variable",
								 [NSNumber numberWithLong:10],        @"length",
								 nil];
    [dataDictionary setObject:aDictionary forKey:@"Levels"];
    
    return dataDictionary;
}

@end

@implementation ORAmi286Model (private)
- (void) runStarted:(NSNotification*)aNote
{
}

- (void) runStopped:(NSNotification*)aNote
{
}

- (void) timeout
{
	NSLogError(@"AMI 286",@"command timeout",nil);
	[self setLastRequest:nil];
	[self processOneCommandFromQueue];	 //do the next command in the queue
}

- (void) processOneCommandFromQueue
{
	if([cmdQueue count] == 0) return;
	@try {
		NSString* aCmd = [[[cmdQueue objectAtIndex:0] retain] autorelease];
		[cmdQueue removeObjectAtIndex:0];
		if([aCmd isEqualToString:@"++ShipRecords"]){
			if(shipLevels) [self shipLevelValues];
		}
		else {
			if([aCmd rangeOfString:@"?"].location != NSNotFound){
				[self setLastRequest:aCmd];
				[self performSelector:@selector(timeout) withObject:nil afterDelay:3];
			}
			if(![aCmd hasSuffix:@"\r"]) aCmd = [aCmd stringByAppendingString:@"\r"];
			[serialPort writeString:aCmd];
			if(!lastRequest){
				[self performSelector:@selector(processOneCommandFromQueue) withObject:nil afterDelay:.1];
			}
		}
	}
	@catch(NSException* localException) {
	}
}

- (void) process_response:(NSString*)theResponse
{
	if([lastRequest rangeOfString:@":LEV?"].location != NSNotFound){
		int channel = [[lastRequest substringFromIndex:2] intValue] - 1;
		if(channel >= 0 && channel <=3){
			[self setLevel:channel value:[theResponse floatValue]];
		}
	}
	else if([lastRequest rangeOfString:@":FILL:STATE?"].location != NSNotFound){
		int channel = [[lastRequest substringFromIndex:2] intValue] - 1;
		if(channel >= 0 && channel <=3){
			[self setFillStatus:channel value:[theResponse intValue]];
		}
	}
	else if([lastRequest rangeOfString:@":STATUS:ALARM:CONDITION?"].location != NSNotFound){
		int channel = [[lastRequest substringFromIndex:2] intValue] - 1;
		if(channel >= 0 && channel <=3){
			[self setAlarmStatus:channel value:[theResponse intValue]];
		}
	}
	else if([lastRequest rangeOfString:@"*OPC?"].location != NSNotFound){
		//device returns a '1' when finished.
	}
}

- (void) startExpiredTimer:(int) index
{
	if(emailEnabled && (enabledMask&(1<<index))){
		[self stopExpiredTimer:index];
		expiredTimer[index] = [[NSTimer scheduledTimerWithTimeInterval:expiredTime*60 
														 target:self 
													   selector:@selector(changeTimerExpired:)
													   userInfo:nil 
														repeats: NO] retain];
	}
}

- (void) stopExpiredTimer:(int) index
{
	[expiredTimer[index] invalidate];
	[expiredTimer[index] release];
	expiredTimer[index] = nil;
}

- (void) changeTimerExpired: (NSTimer*) aTimer
{
	int i;
	for(i=0;i<4;i++){
		if(enabledMask & (1<<i)) {
			NSString* time = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%m/%d %I:%M %p"];
			[self addReason:[NSString stringWithFormat:@"Chan %d. As of %@ NO CHANGE to Fill state (now %@) for at least %d minutes\n",i,time,[self fillStatusName:fillStatus[i]], expiredTime]];
			[self scheduleStatusSend];
		}
	}
}

- (void) scheduleStatusSend
{
	if(!sendIsScheduled) {
		sendIsScheduled = YES;
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(sendEMails) object:nil];
		[self performSelector:@selector(sendEMails) withObject:nil afterDelay:kAmi286EMailDelay];
	}
}


- (void) sendEMails
{
	if([serialPort isOpen]){ 
		[NSThread detachNewThreadSelector:@selector(eMailThread) toTarget:self withObject:nil];
	}
	else sendIsScheduled = NO;

}

- (void) addReason:(NSString*) aReason
{
	[eMailLock lock];
	if(!eMailReasons){
		eMailReasons = [[NSMutableArray array] retain];
		NSString* time = [[NSCalendarDate date] descriptionWithCalendarFormat:@"%m/%d %I:%M %p"];
		[eMailReasons addObject:[NSString stringWithFormat:@"EMailed originally triggered at %@\n",time]];
	}
	[eMailReasons addObject:aReason];
	[eMailLock unlock];
}

- (void) clearReasons
{
	[eMailLock lock];
	[eMailReasons release];
	eMailReasons = nil;
	[eMailLock unlock];
}

- (void) eMailThread
{
	if(eMailThreadRunning || ![eMailList count]) return;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	[self retain]; //can't have the object go away
	
	eMailThreadRunning = YES;
	
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:11.0]];
	[eMailLock lock];
	
	NSString* hostAddress = [[ApplicationSupport sharedApplicationSupport] hostAddress];
	NSString* receipients = [eMailList componentsJoinedByString:@","];
	NSString* content = [NSString stringWithFormat:@"\n+++++++++++++++++++++++++++++++++++\nAutomatically generated by ORCA\nHost machine:%@\n",hostAddress!=nil?hostAddress:@"<Unable to get host address>"];
	int i;
	content = [content stringByAppendingString:@"---------------------------------------------\n"];
	content = [content stringByAppendingString:@"     Level    Status   FillState  Last Change\n"];
	content = [content stringByAppendingString:@"---------------------------------------------\n"];
	for(i=0;i<4;i++){
		const char* stat;
		const char* fillStat;
		if(i<2){
			stat = [[self fillStatusName:[self fillStatus:i]] cStringUsingEncoding:NSASCIIStringEncoding];
			fillStat = [[self fillStateName:[self fillState:i]] cStringUsingEncoding:NSASCIIStringEncoding];
		}
		else {
			stat = "N/A";
			fillStat = "N/A";
		}
		content = [content stringByAppendingFormat:@"%2d: %5.1f %10s %7s       %@\n",i,level[i],stat,fillStat,[lastChange[i] descriptionWithCalendarFormat:@"%m/%d %I:%M %p"]];
	}
	
	if([eMailReasons count]){
		content = [content stringByAppendingString:@"---------------------------------------------\n"];
		content = [content stringByAppendingString:@"\n\nReasons this alarm was triggered:\n"];
		content = [content stringByAppendingFormat:@"%@\n",[eMailReasons componentsJoinedByString:@""]];
		content = [content stringByAppendingString:@"---------------------------------------------\n"];
		[eMailReasons release];
		eMailReasons = nil;
	}
	
	@synchronized([NSApp delegate]){
		if(content){
			NSFont*       labelFont  = [NSFont fontWithName:@"Monaco" size:12];
			NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys: labelFont,NSFontAttributeName,nil];
			NSAttributedString* theContent = [[NSAttributedString alloc] initWithString:content attributes:attributes];
			ORMailer* mailer = [ORMailer mailer];
			[mailer setTo:receipients];
			[mailer setSubject:@"Orca Ami286 Status"];
			[mailer setBody:theContent];
			[mailer send:self];
		}
	}
	[eMailLock unlock];
	
	eMailThreadRunning = NO;
	sendIsScheduled = NO;

	[self autorelease]; //now it's OK for object to go away
	[pool release];
}

@end