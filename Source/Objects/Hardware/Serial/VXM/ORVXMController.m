//--------------------------------------------------------
// ORVXMController
// Created by Mark  A. Howe on Fri Jul 22 2005
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

#pragma mark ***Imported Files

#import "ORVXMController.h"
#import "ORVXMModel.h"
#import "ORAxis.h"
#import "ORVXMMotor.h"
#import "ORSerialPortModel.h"
#import "ORSerialPortController.h"

@interface ORVXMController (private)
#if !defined(MAC_OS_X_VERSION_10_6) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6 // 10.6-specific
- (void) _saveListPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
- (void) _loadListPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;
#endif
@end

@implementation ORVXMController

#pragma mark ***Initialization

- (id) init
{
	self = [super initWithWindowNibName:@"VXM"];
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void) awakeFromNib
{
	

	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	[numberFormatter setFormat:@"#0.000"];	
	int i;
	for(i=0;i<kNumVXMMotors;i++){
		[[conversionMatrix cellAtRow:i column:0] setTag:i];
		[[speedMatrix cellAtRow:i column:0] setTag:i];
		[[motorEnabledMatrix cellAtRow:i column:0] setTag:i];
		[[positionMatrix cellAtRow:i column:0] setTag:i];
		[[targetMatrix cellAtRow:i column:0] setTag:i];
		[[addButtonMatrix cellAtRow:i column:0] setTag:i];
		[[absMotionMatrix cellAtRow:i column:0] setTag:i];
		[[homePlusMatrix cellAtRow:i column:0] setTag:i];
		[[homeMinusMatrix cellAtRow:i column:0] setTag:i];
		
		[[conversionMatrix cellAtRow:i column:0]	setFormatter:numberFormatter];
	}
	[self setFormats];
    [super awakeFromNib];
}

- (void) setFormats
{
	int i;
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	if([model displayRaw]) [numberFormatter setFormat:@"#0"];
	else				   [numberFormatter setFormat:@"#0.000"];
	for(i=0;i<kNumVXMMotors;i++){
		[[positionMatrix cellAtRow:i column:0]		setFormatter:numberFormatter];
		[[speedMatrix cellAtRow:i column:0]		setFormatter:numberFormatter];
		[[targetMatrix cellAtRow:i column:0]		setFormatter:numberFormatter];
	}
	[speedMatrix setNeedsDisplay];
	[positionMatrix setNeedsDisplay];
	[targetMatrix setNeedsDisplay];
}

#pragma mark ***Notifications

- (void) registerNotificationObservers
{
	NSNotificationCenter* notifyCenter = [NSNotificationCenter defaultCenter];
    [super registerNotificationObservers];
    [notifyCenter addObserver : self
                     selector : @selector(updateButtons:)
                         name : ORRunStatusChangedNotification
                       object : nil];
    
    [notifyCenter addObserver : self
                     selector : @selector(updateButtons:)
                         name : ORVXMLock
                        object: nil];
	
    [notifyCenter addObserver : self
                     selector : @selector(positionChanged:)
                         name : ORVXMMotorPositionChanged
                       object : model];
                       
   [notifyCenter addObserver : self
                     selector : @selector(motorEnabledChanged:)
                         name : ORVXMMotorEnabledChanged
                       object : model];

	[notifyCenter addObserver : self
                     selector : @selector(absoluteMotionChanged:)
                         name : ORVXMMotorAbsMotionChanged
                       object : model];

   [notifyCenter addObserver : self
                     selector : @selector(conversionChanged:)
                         name : ORVXMMotorConversionChanged
                       object : model];
	
    [notifyCenter addObserver : self
                     selector : @selector(speedChanged:)
                         name : ORVXMMotorSpeedChanged
                       object : model];      

    [notifyCenter addObserver : self
                     selector : @selector(motorTypeChanged:)
                         name : ORVXMMotorTypeChanged
                       object : model];

    
	[notifyCenter addObserver : self
                     selector : @selector(targetChanged:)
                         name : ORVXMMotorTargetChanged
                       object : model];      
		
	[notifyCenter addObserver : self
                     selector : @selector(updateCmdTable:)
                         name : ORVXMModelCmdQueueChanged
                       object : model]; 	
	
    [notifyCenter addObserver : self
                     selector : @selector(displayRawChanged:)
                         name : ORVXMModelDisplayRawChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(syncWithRunChanged:)
                         name : ORVXMModelSyncWithRunChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(repeatCmdsChanged:)
                         name : ORVXMModelRepeatCmdsChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(repeatCountChanged:)
                         name : ORVXMModelRepeatCountChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(stopRunWhenDoneChanged:)
                         name : ORVXMModelStopRunWhenDoneChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(cmdIndexChanged:)
                         name : ORVXMModelCmdIndexChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(numTimesToRepeatChanged:)
                         name : ORVXMModelNumTimesToRepeatChanged
						object: model];
	
    [notifyCenter addObserver : self
                     selector : @selector(shipRecordsChanged:)
                         name : ORVXMModelShipRecordsChanged
						object: model];

	[notifyCenter addObserver : self
                     selector : @selector(itemsAdded:)
                         name : ORVXMModelListItemsAdded
                       object : model];	
	
	[notifyCenter addObserver : self
                     selector : @selector(itemsRemoved:)
                         name : ORVXMModelListItemsRemoved
                       object : model];	
	
    [notifyCenter addObserver : self
                     selector : @selector(cmdTypeExecutingChanged:)
                         name : ORVXMModelCmdTypeExecutingChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(customCmdChanged:)
                         name : ORVXMModelCustomCmdChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(waitingChanged:)
                         name : ORVXMModelWaitingChanged
						object: model];

    [notifyCenter addObserver : self
                     selector : @selector(useCmdQueueChanged:)
                         name : ORVXMModelUseCmdQueueChanged
						object: model];
    
    [notifyCenter addObserver : self
                     selector : @selector(updateButtons:)
                         name : ORSerialPortModelPortStateChanged
						object: model];

    [serialPortController registerNotificationObservers];

    
}

- (void) updateWindow
{
    [super updateWindow];
    [self updateButtons:nil];
    [self positionChanged:nil];
	[self conversionChanged:nil];
    [self motorEnabledChanged:nil];
    [self speedChanged:nil];
    [self motorTypeChanged:nil];
    [self targetChanged:nil];
    [self updateCmdTable:nil];
	[self displayRawChanged:nil];
	[self absoluteMotionChanged:nil];
	[self syncWithRunChanged:nil];
	[self repeatCmdsChanged:nil];
	[self repeatCountChanged:nil];
	[self stopRunWhenDoneChanged:nil];
	[self cmdIndexChanged:nil];
	[self numTimesToRepeatChanged:nil];
	[self shipRecordsChanged:nil];
	[self cmdTypeExecutingChanged:nil];
	[self customCmdChanged:nil];
	[self waitingChanged:nil];
	[self useCmdQueueChanged:nil];
	[serialPortController updateWindow];
}
- (BOOL) portLocked
{
	return [gSecurity isLocked:ORVXMLock];
}

- (void) useCmdQueueChanged:(NSNotification*)aNote
{
	[useCmdQueueMatrix selectCellWithTag: [model useCmdQueue]];
	[self updateButtons:nil];
}

- (void) waitingChanged:(NSNotification*)aNote
{
	[waitingField setStringValue: [model waiting]?@"Waiting For Go":@""];
	[sendGoButton setEnabled:[model waiting]];
}

- (void) customCmdChanged:(NSNotification*)aNote
{
	[customCmdField setStringValue: [model customCmd]];
}

- (void) cmdTypeExecutingChanged:(NSNotification*)aNote
{
	[cmdListExecutingField setStringValue: [model cmdTypeExecuting]==kVXMCmdListExecuting?@"List is Executing":@""];
	[self repeatCountChanged:nil];
	[self updateButtons:nil];
}

- (void) shipRecordsChanged:(NSNotification*)aNote
{
	[shipRecordsCB setIntValue: [model shipRecords]];
}


- (void) numTimesToRepeatChanged:(NSNotification*)aNote
{
	[numTimesToRepeatField setIntValue: [model numTimesToRepeat]];
}

- (void) cmdIndexChanged:(NSNotification*)aNote
{
	[cmdIndexField setIntValue: [model cmdIndex]];
}

- (void) stopRunWhenDoneChanged:(NSNotification*)aNote
{
	[stopRunWhenDoneCB setIntValue: [model stopRunWhenDone]];
}

- (void) repeatCountChanged:(NSNotification*)aNote
{
	NSString* s = @"";
	if([model cmdTypeExecuting] == kVXMCmdListExecuting){
		if(![model repeatCmds] || ([model numTimesToRepeat] < 2))s = @"";
		else s = [NSString stringWithFormat:@"(%d/%d)",[(ORVXMModel*)model repeatCount]+1,[model numTimesToRepeat]];
	}
	[repeatCountField setStringValue: s];
}

- (void) repeatCmdsChanged:(NSNotification*)aNote
{
	[repeatCmdsCB setIntValue: [model repeatCmds]];
	[self updateButtons:nil];
}

- (void) syncWithRunChanged:(NSNotification*)aNote
{
	[syncWithRunCB setIntValue: [model syncWithRun]];
	[self updateButtons:nil];
}

- (void) displayRawChanged:(NSNotification*)aNote
{
	[displayRawMatrix selectCellWithTag: [model displayRaw]];
	[self updateButtons:nil];
	[self setFormats];
	[self speedChanged:nil];
	[self positionChanged:nil];
	[self targetChanged:nil];
}

- (void) updateCmdTable:(NSNotification*)aNotification
{
	[cmdQueueTable reloadData];
}

- (void) conversionChanged:(NSNotification*)aNotification
{
	if(aNotification){
		ORVXMMotor* aMotor = [[aNotification userInfo] objectForKey:@"VMXMotor"];
		[[conversionMatrix cellWithTag:[aMotor motorId]] setFloatValue: [aMotor conversion]];
	}
	else {
		for(id aMotor in [model motors]){
			[[conversionMatrix cellWithTag:[aMotor motorId]] setFloatValue:[aMotor conversion]];
		}
	}
	[self speedChanged:nil];
}

- (void) speedChanged:(NSNotification*)aNotification
{
	if(aNotification){
		ORVXMMotor* aMotor = [[aNotification userInfo] objectForKey:@"VMXMotor"];
		float conversion = 1.0;
		if(![model displayRaw]) conversion = [aMotor conversion];
		[[speedMatrix cellWithTag:[aMotor motorId]] setFloatValue: [aMotor motorSpeed]/conversion];

	}
	else {
		for(id aMotor in [model motors]){
			float conversion = 1.0;
			if(![model displayRaw]) conversion = [aMotor conversion];
			[[speedMatrix cellWithTag:[aMotor motorId]] setFloatValue:[aMotor motorSpeed]/conversion];
		}
	}
}

- (void) motorTypeChanged:(NSNotification*)aNotification
{
	if(aNotification){
		ORVXMMotor* aMotor = [[aNotification userInfo] objectForKey:@"VMXMotor"];
        [[motorTypeMatrix cellAtRow:[aMotor motorId] column:0] selectItemAtIndex:[aMotor motorType]];

        
	}
	else {
		for(id aMotor in [model motors]){
            [[motorTypeMatrix cellAtRow:[aMotor motorId] column:0] selectItemAtIndex:[aMotor motorType]];
		}
	}
}

- (void) positionChanged:(NSNotification*)aNotification
{
	if(aNotification){
		ORVXMMotor* aMotor = [[aNotification userInfo] objectForKey:@"VMXMotor"];
		float conversion = 1.0;
		if(![model displayRaw]) conversion = [aMotor conversion];
		[[positionMatrix cellWithTag:[aMotor motorId]] setFloatValue: [aMotor motorPosition]/conversion];
	}
	else {
		for(id aMotor in [model motors]){
			float conversion = 1.0;
			if(![model displayRaw]) conversion = [aMotor conversion];
			[[positionMatrix cellWithTag:[aMotor motorId]] setFloatValue:[aMotor motorPosition]/conversion];
		}
	}
}

- (void) targetChanged:(NSNotification*)aNotification
{
	if(aNotification){
		ORVXMMotor* aMotor = [[aNotification userInfo] objectForKey:@"VMXMotor"];
		float conversion = 1.0;
		if(![model displayRaw]) conversion = [aMotor conversion];
		[[targetMatrix cellWithTag:[aMotor motorId]] setFloatValue: [aMotor targetPosition]/conversion];
	}
	else {
		for(id aMotor in [model motors]){
			float conversion = 1.0;
			if(![model displayRaw]) conversion = [aMotor conversion];
			[[targetMatrix cellWithTag:[aMotor motorId]] setFloatValue:[aMotor targetPosition]/conversion];
		}
	}
}

- (void) checkGlobalSecurity
{
    BOOL secure = [[[NSUserDefaults standardUserDefaults] objectForKey:OROrcaSecurityEnabled] boolValue];
    [gSecurity setLock:ORVXMLock to:secure];
    [lockButton setEnabled:secure];
}

- (void) updateButtons:(NSNotification*)aNotification
{

    BOOL runInProgress		= [gOrcaGlobals runInProgress];
    BOOL lockedOrRunningMaintenance = [gSecurity runInProgressButNotType:eMaintenanceRunType orIsLocked:ORVXMLock];
    BOOL locked				= [gSecurity isLocked:ORVXMLock];
	BOOL displayRaw			= [model displayRaw];
	BOOL syncWithRun		= [model syncWithRun];
	int cmdExecuting		= [model cmdTypeExecuting];
	BOOL useCmdQueue		= [model useCmdQueue];
	
	[serialPortController updateButtons:locked];
    
    [lockButton setState: locked];

    [getPositionButton setEnabled:!locked];
	
	[manualStartButton setEnabled:!locked && !syncWithRun && !cmdExecuting && useCmdQueue];
	[stopAllMotionButton setEnabled: cmdExecuting ];
	[loadListButton setEnabled:!cmdExecuting ];
	[removeAllCmdsButton setEnabled:!cmdExecuting];

	[syncWithRunCB setEnabled:!locked && !cmdExecuting && useCmdQueue];
	[stopWithRunButton setEnabled:!locked && !cmdExecuting && useCmdQueue];
	[repeatCmdsCB setEnabled:!locked && !cmdExecuting && useCmdQueue];
	[numTimesToRepeatField setEnabled:!locked && [model repeatCmds] && !cmdExecuting && useCmdQueue];
	[stopGoNextCmdButton setEnabled: cmdExecuting && useCmdQueue];
	
    [motorTypeMatrix setEnabled: !locked && !cmdExecuting];

	[addCustomCmdButton setEnabled: !cmdExecuting];
	[addCustomCmdButton setTitle:[model useCmdQueue]?@"Add Custom Cmd": @"Execute Cmd"];
	[zeroCounterButton setEnabled:!locked && !cmdExecuting];
	[zeroCounterButton setTitle:[model useCmdQueue]?@"Add Zero Cmd": @"Execute Zero Cmd..."];
	
	for(id aMotor in [model motors]){
		int i = [aMotor motorId];
		BOOL motorEnabled = [aMotor motorEnabled];
        BOOL absMotion = [aMotor absoluteMotion];
		[[conversionMatrix cellWithTag:i] setEnabled:!locked && motorEnabled && !displayRaw && !cmdExecuting];
		[[motorEnabledMatrix cellWithTag:i] setEnabled:!locked && !cmdExecuting];
		[[speedMatrix cellWithTag:i] setEnabled:!locked && motorEnabled && !cmdExecuting];
		[[absMotionMatrix cellWithTag:i] setEnabled:!locked && motorEnabled  && !cmdExecuting];
		[[addButtonMatrix cellWithTag:i] setEnabled:!locked && motorEnabled && !cmdExecuting];
		[[addButtonMatrix cellWithTag:i] setTitle:absMotion?@"Move Abs":@"Move Rel"];
		[[homePlusMatrix cellWithTag:i] setEnabled:!locked && motorEnabled && !cmdExecuting];
		[[homeMinusMatrix cellWithTag:i] setEnabled:!locked && motorEnabled && !cmdExecuting];
	}

	if([model displayRaw]){
		[speedLabelField setStringValue:@"(stps/sec)"];
		[currentPositionLabelField setStringValue:@"(steps)"];
		[targetLabelField setStringValue:@"(steps)"];
	}
	else {
		[speedLabelField setStringValue:@"(mm/sec)"];
		[currentPositionLabelField setStringValue:@"(mm)"];
		[targetLabelField setStringValue:@"(mm)"];
	}	

    NSString* s = @"";
    if(lockedOrRunningMaintenance){
        if(runInProgress && ![gSecurity isLocked:ORVXMLock])s = @"Not in Maintenance Run.";
    }
    [lockDocField setStringValue:s];

}

- (void) absoluteMotionChanged:(NSNotification*)aNotification
{
	if(aNotification){
		ORVXMMotor* aMotor = [[aNotification userInfo] objectForKey:@"VMXMotor"];
		[[absMotionMatrix cellWithTag:[aMotor motorId]] setIntValue: [aMotor absoluteMotion]];
	}
	else {
		for(id aMotor in [model motors]){
			[[absMotionMatrix cellWithTag:[aMotor motorId]] setIntValue:[aMotor absoluteMotion]];
		}
	}
    [self updateButtons:nil];
}

- (void) motorEnabledChanged:(NSNotification*)aNotification
{
	if(aNotification){
		ORVXMMotor* aMotor = [[aNotification userInfo] objectForKey:@"VMXMotor"];
		[[motorEnabledMatrix cellWithTag:[aMotor motorId]] setIntValue: [aMotor motorEnabled]];
	}
	else {
		for(id aMotor in [model motors]){
			[[motorEnabledMatrix cellWithTag:[aMotor motorId]] setIntValue:[aMotor motorEnabled]];
		}
	}
	[self updateButtons:nil];
}

- (BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
    if ([menuItem action] == @selector(cut:)) {
        return [cmdQueueTable selectedRow] >= 0 ;
    }
    else if ([menuItem action] == @selector(delete:)) {
        return [cmdQueueTable selectedRow] >= 0;
    }
	[super validateMenuItem:menuItem];
	return YES;
}
- (void) itemsAdded:(NSNotification*)aNote
{
	int index = [[[aNote userInfo] objectForKey:@"Index"] intValue];
	index = MIN(index,[model cmdQueueCount]);
	index = MAX(index,0);
	[cmdQueueTable reloadData];
	NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:index];
	[cmdQueueTable selectRowIndexes:indexSet byExtendingSelection:NO];
}

- (void) itemsRemoved:(NSNotification*)aNote
{
	int index = [[[aNote userInfo] objectForKey:@"Index"] intValue];
	index = MIN(index,[model cmdQueueCount]-1);
	index = MAX(index,0);
	[cmdQueueTable reloadData];
	NSIndexSet* indexSet = [NSIndexSet indexSetWithIndex:index];
	[cmdQueueTable selectRowIndexes:indexSet byExtendingSelection:NO];
}

#pragma mark ***Actions
- (void) useCmdQueueAction:(id)sender
{
	int tag = [[useCmdQueueMatrix selectedCell] tag];
	[model setUseCmdQueue:tag];	
}

- (IBAction) customCmdAction:(id)sender
{
	[model setCustomCmd:[sender stringValue]];	
}

- (IBAction) removeItemAction:(id)sender
{
	NSIndexSet* theSet = [cmdQueueTable selectedRowIndexes];
	NSUInteger current_index = [theSet firstIndex];
    if(current_index != NSNotFound){
		[model removeItemAtIndex:current_index];
	}
	//[self setButtonStates];
}

- (IBAction) delete:(id)sender
{
    [self removeItemAction:nil];
}

- (IBAction) cut:(id)sender
{
    [self removeItemAction:nil];
}

- (IBAction) shipRecordsAction:(id)sender
{
	[model setShipRecords:[sender intValue]];	
}

- (IBAction) motorTypeAction:(id)sender
{
    ORVXMMotor* aMotor = [model motor:[sender selectedRow]];
    [aMotor setMotorType:[[sender selectedCell] indexOfSelectedItem]];
}

- (IBAction) manualStateAction:(id)sender
{
	[model manualStart];
}

- (IBAction) removeAllAction:(id)sender
{
	[model removeAllCmds];
}

- (IBAction) numTimesToRepeatAction:(id)sender
{
	[model setNumTimesToRepeat:[sender intValue]];	
}

- (IBAction) stopRunWhenDoneAction:(id)sender
{
	[model setStopRunWhenDone:[sender intValue]];	
}

- (IBAction) repeatCmdsAction:(id)sender
{
	[model setRepeatCmds:[sender intValue]];	
}

- (IBAction) repeatCountAction:(id)sender
{
	[(ORVXMModel*)model setRepeatCount:[sender intValue]];	
}

- (IBAction) syncWithRunAction:(id)sender
{
	[model setSyncWithRun:[sender intValue]];	
}

- (IBAction) displayRawAction:(id)sender
{
	int tag = [[displayRawMatrix selectedCell] tag];
	[model setDisplayRaw:tag];	
}

- (IBAction) lockAction:(id) sender
{
    [gSecurity tryToSetLock:ORVXMLock to:[sender intValue] forWindow:[self window]];
}

- (IBAction) stopAllAction:(id)sender
{
    [model stopAllMotion];
}

- (IBAction) goToNextCommandAction:(id)sender
{
    [model goToNexCommand];
}

- (IBAction) conversionAction:(id)sender
{
    [[model motor:[[sender selectedCell]tag]] setConversion:[[sender selectedCell] floatValue]];
}

- (IBAction) speedAction:(id)sender
{
	ORVXMMotor* aMotor = [model motor:[[sender selectedCell]tag]];
	float conversion = 1.0;
	if(![model displayRaw]) conversion = [aMotor conversion];
	[aMotor setMotorSpeed:(int)[[sender selectedCell] floatValue]*conversion];
}

- (IBAction) targetPositionAction:(id)sender
{
	ORVXMMotor* aMotor = [model motor:[[sender selectedCell]tag]];
	float conversion = 1.0;
	if(![model displayRaw]) conversion = [aMotor conversion];
	[aMotor setTargetPosition:[[sender selectedCell] floatValue]*conversion];
}

- (IBAction) motorEnabledAction:(id)sender
{
	[[model motor:[[sender selectedCell]tag]] setMotorEnabled:[[sender selectedCell] intValue]];
}

- (IBAction) absoluteMotionAction:(id)sender
{
	[[model motor:[[sender selectedCell]tag]] setAbsoluteMotion:[[sender selectedCell] intValue]];
}

- (IBAction) addButtonAction:(id)sender
{
	[self endEditing];
	[model addCmdFromTableFor:[[sender selectedCell]tag]];
}

- (IBAction) addZeroCounterAction:(id)sender
{
    if([model useCmdQueue])[model addZeroCmd];
    else {
        int choice = NSRunAlertPanel(@"About to reset position counter to zero!",@"Is this really what you want?\n",@"Cancel",@"Yes, Do it",nil);
        if(choice == NSAlertAlternateReturn){
            [model addZeroCmd];
        }
    }
}

- (IBAction) addHomePlusAction:(id)sender
{
	[model addHomePlusCmdFor:[[sender selectedCell]tag]];
}

- (IBAction) addHomeMinusAction:(id)sender
{
	[model addHomeMinusCmdFor:[[sender selectedCell]tag]];
}

- (IBAction) addCustomCmdAction:(id)sender
{
	[self endEditing];
	[model addCustomCmd];
}

- (IBAction) sendGoAction:(id)sender
{
	[model sendGo];
}

- (IBAction) saveListAction:(id)sender
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setPrompt:@"Save To File"];
    [savePanel setCanCreateDirectories:YES];
    
    NSString* startingDir;
    
	NSString* fullPath = [[model listFile] stringByExpandingTildeInPath];
    if(fullPath) startingDir = [fullPath stringByDeletingLastPathComponent];
    else		 startingDir = NSHomeDirectory();
    
#if defined(MAC_OS_X_VERSION_10_6) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6 // 10.6-specific
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:startingDir]];
    [savePanel setNameFieldLabel:@"Save to:"];
    [savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton){
            [model saveListTo:[[savePanel URL]path]];
        }
    }];
#else 		
    [savePanel beginSheetForDirectory:startingDir
                                 file:@"VXMCmdList"
                       modalForWindow:[self window]
                        modalDelegate:self
                       didEndSelector:@selector(_saveListPanelDidEnd:returnCode:contextInfo:)
                          contextInfo:NULL];
#endif	
}

- (IBAction) loadListAction:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setPrompt:@"Choose"];
    NSString* startingDir;
    if([model listFile]) startingDir = [[model listFile] stringByDeletingLastPathComponent];
    else				 startingDir = NSHomeDirectory();
	
#if defined(MAC_OS_X_VERSION_10_6) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6 // 10.6-specific
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:startingDir]];
    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton){
            [model loadListFrom:[[openPanel URL]path]];
            [cmdQueueTable reloadData];
        }
    }];
#else
    [openPanel beginSheetForDirectory:startingDir
                                 file:nil
                                types:nil
                       modalForWindow:[self window]
                        modalDelegate:self
                       didEndSelector:@selector(_loadListPanelDidEnd:returnCode:contextInfo:)
                          contextInfo:NULL];
#endif
}


#pragma mark •••Table Data Source
- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [model cmdQueueCount];
}

- (id) tableView:(NSTableView *) aTableView objectValueForTableColumn:(NSTableColumn *) aTableColumn row:(int) rowIndex
{
	if([[aTableColumn identifier] isEqualToString:@"Command"]) return [model cmdQueueCommand:rowIndex];
	else if([[aTableColumn identifier] isEqualToString:@"CmdIndex"]) {
		if(rowIndex == [model cmdIndex])return @"√";
		else return @"";
	}
	else return  [model cmdQueueDescription:rowIndex];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	ORVXMMotorCmd* aCmd = [model motorCmd:rowIndex];
	if(aCmd){
		if([[aTableColumn identifier] isEqualToString:@"Command"])			aCmd.cmd         = anObject;
		else if([[aTableColumn identifier] isEqualToString:@"Description"])	aCmd.description = anObject;
	}
}	

@end

@implementation ORVXMController (private)
#if !defined(MAC_OS_X_VERSION_10_6) && MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6 // 10.6-specific
- (void) _saveListPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    if(returnCode){
        [model saveListTo:[sheet filename]];
    }
}
- (void) _loadListPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    if(returnCode){
        [model loadListFrom:[sheet filename]];
        [cmdQueueTable reloadData];
    }
}

#endif
@end


