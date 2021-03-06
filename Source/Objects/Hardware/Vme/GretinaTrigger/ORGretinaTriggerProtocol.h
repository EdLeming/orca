//
//  ORGretinaTriggerProtocol
//  Orca
//
//  Created by Mark Howe on Thurs Aug 17,2017
//  Copyright (c) 2017 University of North Carolina. All rights reserved.
//-----------------------------------------------------------
//This program was prepared for the Regents of the University of
//North Carolina Department of Physics and Astrophysics
//sponsored in part by the United States
//Department of Energy (DOE) under Grant #DE-FG02-97ER41020.
//The University has certain rights in the program pursuant to
//the contract and the program should not be copied or distributed
//outside your organization.  The DOE and the University of
//North Carolina reserve all rights in the program. Neither the authors,
//University of North Carolina, or U.S. Government make any warranty,
//express or implied, or assume any liability or responsibility
//for the use of this software.
//-------------------------------------------------------------

enum {
    kSerDesIdle,
    kSerDesSetup,
    kSetDigitizerClkSrc,
    kFlushFifo,
    kReleaseClkManager,
    kPowerUpRTPower,
    kSetMasterLogic,
    kSetSDSyncBit,
    kSerDesError,
};

@protocol ORGretinaTriggerProtocol <NSObject>

- (void) setInitState:(short)aState;
- (short) initState;
- (void) stepSerDesInit;
- (void) setClockSource:(short)aClockSource;
- (BOOL) isLocked;
- (void) resetSingleFIFO;
- (NSString*) fullID;

@end
