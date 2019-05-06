#import "AudioRecorderAPI.h"
#import <Cordova/CDV.h>

@implementation AudioRecorderAPI

#define RECORDINGS_FOLDER [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]

- (void)findConnectedHeadSet:(AVAudioSession *)audioSession {
    NSArray<AVAudioSessionPortDescription *> *availableInputs = [audioSession availableInputs];
    
    for (int i=0; i < [availableInputs count]; i++) {
        audioSessionPortDescription = [availableInputs objectAtIndex:i];
        
        NSLog(@"AudioRecorderAPI find connected HeadSet: %@ %@", [audioSessionPortDescription portName], [audioSessionPortDescription portType]);
        
        if (
            [[audioSessionPortDescription portType] isEqualToString:AVAudioSessionPortHeadphones] ||
            [[audioSessionPortDescription portType] isEqualToString:AVAudioSessionPortBluetoothHFP] ||
            [[audioSessionPortDescription portType] isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
            [[audioSessionPortDescription portType] isEqualToString:AVAudioSessionPortHeadsetMic] ||
            [[audioSessionPortDescription portType] isEqualToString:AVAudioSessionPortBluetoothLE]
            ) {
            
            break;
        }
    }
}


- (void)setHeadSetPreferred:(AVAudioSession *)audioSession {
    
    if (audioSessionPortDescription == nil) return;
    
    NSLog(@"AudioRecorderAPI setHeadSetPreferred: %@ %@", [audioSessionPortDescription portName], [audioSessionPortDescription portType]);
    [audioSession setPreferredInput:audioSessionPortDescription error:nil];
    
}

- (void)record:(CDVInvokedUrlCommand*)command {
    _command = command;
    if ([_command.arguments count] > 0) {
        duration = [_command.arguments objectAtIndex:0];
    }
    else {
        duration = nil;
    }
    
    [self.commandDelegate runInBackground:^{
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        
        [self findConnectedHeadSet:audioSession];
                
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"PERMISSION_CALL"];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
        
        NSError *err = nil;
        __block NSString *msg = nil;
        [audioSession requestRecordPermission:^(BOOL granted) {
            if (granted) {
                NSLog(@"AudioRecorderAPI Permission granted");
            }
            else {
                msg = @"Permission denied";
                NSLog(@"AudioRecorderAPI Permission denied");
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Permission was denied"];
                [pluginResult setKeepCallbackAsBool:NO];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
            }
        }];
        
        if (msg != nil|| msg.length > 0 ){
            return ;
        }
        
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
        if (err)
        {
            NSLog(@"AudioRecorderAPI setCategory %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        }
        
        
        err = nil;
        [audioSession setActive:YES error:&err];
        if (err)
        {
            NSLog(@"AudioRecorderAPI setActive %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        }
        
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
        AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute, sizeof (audioRouteOverride),&audioRouteOverride);
        
        NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
        [recordSettings setObject:[NSNumber numberWithInt: kAudioFormatMPEG4AAC] forKey: AVFormatIDKey];
        [recordSettings setObject:[NSNumber numberWithFloat:44100.0] forKey: AVSampleRateKey];
        [recordSettings setObject:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
        [recordSettings setObject:[NSNumber numberWithInt:44100] forKey:AVEncoderBitRateKey];
        [recordSettings setObject:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
        [recordSettings setObject:[NSNumber numberWithInt: AVAudioQualityHigh] forKey: AVEncoderAudioQualityKey];
        [recordSettings setObject:[NSNumber numberWithInt: AVAudioQualityHigh] forKey: AVEncoderAudioQualityForVBRKey];
        [self setHeadSetPreferred:audioSession];
        
        // Create a new dated file
        NSString *uuid = [[NSUUID UUID] UUIDString];
        recorderFilePath = [NSString stringWithFormat:@"%@/%@.m4a", RECORDINGS_FOLDER, uuid];
        NSLog(@"AudioRecorderAPI recording file path: %@", recorderFilePath);
        
        NSURL *url = [NSURL fileURLWithPath:recorderFilePath];
        err = nil;
        recorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSettings error:&err];
        if(!recorder){
            NSLog(@"AudioRecorderAPI recorder: %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
            return;
        }
        
        [recorder setDelegate:self];
        
        if (![recorder prepareToRecord]) {
            NSLog(@"AudioRecorderAPI prepareToRecord failed");
            return;
        }
        if (duration == nil || duration.integerValue == -1) {
            if (![recorder record]) {
                NSLog(@"AudioRecorderAPI record failed");
                return;
            } else {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"RECORD_START"];
                [pluginResult setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
                
            }
        }
        else {
            if (![recorder recordForDuration:(NSTimeInterval)[duration intValue]]) {
                NSLog(@"AudioRecorderAPI recordForDuration failed");
                return;
            }
        }
        
    }];
}

- (void)stop:(CDVInvokedUrlCommand*)command {
    _command = command;
    NSLog(@"AudioRecorderAPI stopRecording");
    [recorder stop];
    NSLog(@"AudioRecorderAPI stopped");
}

- (void)playback:(CDVInvokedUrlCommand*)command {
    _command = command;
    [self.commandDelegate runInBackground:^{
        NSLog(@"AudioRecorderAPI recording playback");
        NSURL *url = [NSURL fileURLWithPath:recorderFilePath];
        NSError *err;
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
        player.numberOfLoops = 0;
        player.delegate = self;
        [player prepareToPlay];
        [player play];
        if (err) {
            NSLog(@"AudioRecorderAPI %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        }
        NSLog(@"AudioRecorderAPI playing");
    }];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSLog(@"AudioRecorderAPI audioPlayerDidFinishPlaying");
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"playbackComplete"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    NSURL *url = [NSURL fileURLWithPath: recorderFilePath];
    NSError *err = nil;
    NSData *audioData = [NSData dataWithContentsOfFile:[url path] options: 0 error:&err];
    if(!audioData) {
        NSLog(@"AudioRecorderAPI audio data: %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
    } else {
        NSLog(@"AudioRecorderAPI recording saved: %@", recorderFilePath);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:recorderFilePath];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
    }
}

@end

