#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioServices.h>

@interface AudioRecorderAPI : CDVPlugin {
    NSString *recorderFilePath;
    NSNumber *duration;
    AVAudioRecorder *recorder;
    AVAudioPlayer *player;
    AVAudioSessionPortDescription *audioSessionPortDescription;
    CDVPluginResult *pluginResult;
    CDVInvokedUrlCommand *_command;
}

- (void)record:(CDVInvokedUrlCommand*)command;
- (void)stop:(CDVInvokedUrlCommand*)command;
- (void)playback:(CDVInvokedUrlCommand*)command;

@end
