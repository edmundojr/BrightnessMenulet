//
//  DDCControls.m
//  BrightnessMenulet
//
//  Created by Kalvin Loc on 9/17/14.
//
//

#import "DDCControls.h"

@interface DDCControls ()

@end

@implementation DDCControls

+ (DDCControls *)singleton{
    static dispatch_once_t pred = 0;
    static DDCControls *shared;
    dispatch_once(&pred, ^{
        shared = [[self alloc] init];
    });
    
    return shared;
}

- (id)init{
    if(self = [super init]){
        NSString *profilePath = [[NSBundle mainBundle] pathForResource:@"userPresets" ofType:@"plist"];
        _profiles = [[NSMutableDictionary alloc] initWithContentsOfFile:profilePath];
    }
    
    return self;
}

// // EDID credits to https://github.com/kfix/ddcctl
NSString *EDIDString(char *string) {
    NSString *temp = [[NSString alloc] initWithBytes:string length:13 encoding:NSASCIIStringEncoding];
    return ([temp rangeOfString:@"\n"].location != NSNotFound)
    ? [[temp componentsSeparatedByString:@"\n"] objectAtIndex:0]
    : temp;
}

- (struct DDCReadResponse)readDisplay:(CGDirectDisplayID)display_id controlValue:(int)control{
    struct DDCReadCommand read_command;
    read_command.control_id = control;

    ddc_read(display_id, &read_command);
    return read_command.response;
}

- (void)changeDisplay:(CGDirectDisplayID)display_id control:(int)control withValue:(int)value{
    struct DDCWriteCommand write_command;
    write_command.control_id = control;
    write_command.new_value = value;
    
    ddc_write(display_id, &write_command);
}

- (void)refreshScreens{
    NSLog(@"DDCControls: Refreshing Screens");
    NSMutableArray* newScreens = [NSMutableArray array];
    
    for(NSScreen* screen in [NSScreen screens]) {
        // Must call unsignedIntValue to get val
        // Leave as NSNumber to store in dictionary
        NSNumber* screenNumber = screen.deviceDescription[@"NSScreenNumber"];
        
        struct EDID edid = {};
        EDIDRead([screenNumber unsignedIntegerValue], &edid);
        
        NSString* name;
        NSString* serial;
        for (NSValue *value in @[[NSValue valueWithPointer:&edid.descriptor1], [NSValue valueWithPointer:&edid.descriptor2], [NSValue valueWithPointer:&edid.descriptor3], [NSValue valueWithPointer:&edid.descriptor4]]) {
            union descriptor *des = value.pointerValue;
            switch (des->text.type) {
                case 0xFF:
                    serial = EDIDString(des->text.data);
                    break;
                case 0xFC:
                    name = EDIDString(des->text.data);
                    break;
            }
        }
        
        if(name == nil || [name isEqualToString:@"Color LCD"]) continue; // don't want to manage invalid screen or integrated LCD
        
        NSMutableDictionary* scr = [NSMutableDictionary dictionaryWithDictionary:@{
                              Model : name,
                              ScreenNumber : screenNumber,
                              Serial : serial,
                              CurrentBrightness : @-1,
                              MaxBrightness : @-1,
                              CurrentContrast : @-1,
                              MaxContrast : @-1
                              }];
        
        [newScreens addObject:scr];
        NSLog(@"DDCControls: Found %@ - %@", name, screenNumber);
    }
    
    if([newScreens count] == 0)
        NSLog(@"DDCControls: No screens found");
    else{
        _screens = [newScreens copy];
        [self refreshScreenValues];
    }
}

- (void)refreshScreenValues{
    for(NSMutableDictionary* scr in _screens){
        struct DDCReadResponse cBrightness = [self readDisplay:[scr[ScreenNumber] unsignedIntegerValue] controlValue:BRIGHTNESS];
        struct DDCReadResponse cContrast = [self readDisplay:[scr[ScreenNumber] unsignedIntegerValue] controlValue:CONTRAST];
        
        [scr setObject:[NSNumber numberWithUnsignedChar:cBrightness.current_value] forKey:CurrentBrightness];
        [scr setObject:[NSNumber numberWithUnsignedChar:cBrightness.max_value] forKey:MaxBrightness];
        [scr setObject:[NSNumber numberWithUnsignedChar:cContrast.current_value] forKey:CurrentContrast];
        [scr setObject:[NSNumber numberWithUnsignedChar:cContrast.max_value] forKey:MaxContrast];

        NSLog(@"%@ set BR %d CR %d", scr[Model] , cBrightness.current_value, cContrast.current_value);
    }
}

- (void)applyProfile:(NSString*)profile{
    NSArray* profileInfo;
    
    if((profileInfo = _profiles[profile])){
        for(int i=0; i<[profileInfo count]; i++){
            NSDictionary* scr = profileInfo[i];
            [self setScreen:scr brightness:[scr[CurrentBrightness] intValue]];
            [self setScreen:scr contrast:[scr[CurrentBrightness] intValue]];
        }
    }else
        NSLog(@"Unknown profile %@", profile);
}

- (NSDictionary*)screenForDisplayName:(NSString*)name {
    for(NSDictionary* scr in _screens)
        if ([scr[@"Model"] isEqualToString:name])
            return scr;
    
    return nil;
}

- (NSDictionary*)screenForDisplayID:(CGDirectDisplayID)display_id {
    for(NSDictionary* scr in _screens)
        if ([scr[@"ScreenNumber"] unsignedIntegerValue] == display_id)
            return scr;
    
    return nil;
}

- (void)setScreenID:(CGDirectDisplayID)display_id brightness:(int)brightness{
    NSDictionary* scr = [self screenForDisplayID:display_id];
    if(scr)
        [self setScreen:scr brightness:brightness];
}

- (void)setScreenID:(CGDirectDisplayID)display_id contrast:(int)contrast{
    NSDictionary* scr = [self screenForDisplayID:display_id];
    if(scr)
        [self setScreen:scr contrast:contrast];
}

- (void)setScreen:(NSDictionary*)scr brightness:(int)brightness {
    CGDirectDisplayID scrID = [scr[ScreenNumber] unsignedIntegerValue];
    
    [self changeDisplay:scrID control:BRIGHTNESS withValue:brightness];
    [scr setValue:[NSNumber numberWithInt:brightness] forKey:CurrentBrightness];
    
    NSLog(@"%ud Brightness changed to %d", scrID, brightness);
}

- (void)setScreen:(NSDictionary*)scr contrast:(int)contrast {
    CGDirectDisplayID scrID = [scr[ScreenNumber] unsignedIntegerValue];
    
    [self changeDisplay:scrID control:CONTRAST withValue:contrast];
    [scr setValue:[NSNumber numberWithInt:contrast] forKey:CurrentBrightness];
    
    NSLog(@"%ud Contrast changed to %d", scrID, contrast);
}

@end