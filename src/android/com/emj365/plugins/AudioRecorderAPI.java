package com.emj365.plugins;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;

import android.media.MediaRecorder;
import android.media.MediaPlayer;
import android.media.AudioManager;
import android.os.CountDownTimer;
import android.content.Context;
import android.content.pm.PackageManager;
import android.Manifest;
import android.util.Log;

import java.util.UUID;
import java.io.FileInputStream;
import java.io.File;
import java.io.IOException;
import java.lang.Throwable;

public class AudioRecorderAPI extends CordovaPlugin {
    private static final String REQUEST_RECORD = Manifest.permission.RECORD_AUDIO;
    private static final int CALLBACK_CODE = 156646559;

    private MediaRecorder myRecorder;
    private String outputFile;
    private CountDownTimer countDowntimer;

    private CallbackContext callbackContext;
    private Integer seconds;

    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
        Context context = cordova.getActivity().getApplicationContext();

        Log.d("AudioRecorderAPI", "-in-> " + action);
        if (args.length() >= 1) {
            seconds = args.getInt(0);
        } else {
            seconds = -1;
        }
        if ("record".equals(action)) {
            this.callbackContext = callbackContext;

            if (!cordova.hasPermission(REQUEST_RECORD)) {
                cordova.requestPermission(this, CALLBACK_CODE, REQUEST_RECORD);
                Log.d("AudioRecorderAPI", "AUDIO_RECORD_PERMISSION_CALL");
                sendPluginResult(PluginResult.Status.OK, "PERMISSION_CALL");
                return true;
            } else {
                return record(context);
            }
        }

        if ("stop".equals(action)) {
            if (countDowntimer != null) {
                countDowntimer.cancel();
                countDowntimer = null;
            }
            stopRecord(callbackContext);
            return true;
        }

        if ("playback".equals(action)) {
            MediaPlayer mp = new MediaPlayer();
            mp.setAudioStreamType(AudioManager.STREAM_MUSIC);

            try {
                FileInputStream fis = new FileInputStream(new File(outputFile));
                mp.setDataSource(fis.getFD());
            } catch (IllegalArgumentException e) {
                e.printStackTrace();
            } catch (SecurityException e) {
                e.printStackTrace();
            } catch (IllegalStateException e) {
                e.printStackTrace();
            } catch (IOException e) {
                e.printStackTrace();
            }
            try {
                mp.prepare();
            } catch (IllegalStateException e) {
                e.printStackTrace();
            } catch (IOException e) {
                e.printStackTrace();
            }
            mp.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
                public void onCompletion(MediaPlayer mp) {
                    callbackContext.success("playbackComplete");
                }
            });
            mp.start();
            return true;
        }

        return false;
    }

    private void sendPluginResult(PluginResult.Status status, String message) {
        PluginResult pr = new PluginResult(status, message);
        pr.setKeepCallback(true);
        this.callbackContext.sendPluginResult(pr);
    }

    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {

        // only my request shall be handled
        if (requestCode != CALLBACK_CODE)
            return;

        int grandResult = PackageManager.PERMISSION_DENIED;

        // permission and grant result have to have the same index
        for (int idx = 0; idx < permissions.length; idx++) {
            if (Manifest.permission.RECORD_AUDIO.equals(permissions[idx]))
                grandResult = grantResults[idx];
        }

        switch (grandResult) {
            case PackageManager.PERMISSION_DENIED:
                this.callbackContext.error("Permission was denied");
                break;

            case PackageManager.PERMISSION_GRANTED:
                this.record(cordova.getActivity().getApplicationContext());
                break;
            default:
                String msg = "Permission grand result: " + grandResult + "  is unkown.";
                Log.w("AudioRecorderAPI", msg);
                this.callbackContext.error(msg);
                break;
        }
    }

    private boolean record(Context context) {
        outputFile = context.getFilesDir().getAbsoluteFile() + "/" + UUID.randomUUID().toString() + ".m4a";
        myRecorder = new MediaRecorder();
        myRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        myRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
        myRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
        myRecorder.setAudioSamplingRate(44100);
        myRecorder.setAudioChannels(1);
        myRecorder.setAudioEncodingBitRate(44100);
        myRecorder.setOutputFile(outputFile);

        try {
            myRecorder.prepare();
            myRecorder.start();
            Log.d("AudioRecorderAPI", "record start");
        } catch (final Exception e) {
            cordova.getThreadPool().execute(new Runnable() {
                public void run() {
                    Log.d("AudioRecorderAPI", "record", e);
                    callbackContext.error(e.getMessage());
                }
            });
            return false;
        }
        if (seconds != -1) {
            countDowntimer = new CountDownTimer(seconds * 1000, 1000) {
                public void onTick(long millisUntilFinished) {
                }

                public void onFinish() {
                    stopRecord(callbackContext);
                }
            };
            countDowntimer.start();
        }

        sendPluginResult(PluginResult.Status.OK, "RECORD_START");

        return true;
    }

    private void stopRecord(final CallbackContext callbackContext) {
        try {
            Log.d("AudioRecorderAPI", "record stop");
            myRecorder.stop();
        } catch (Throwable e) {
            Log.d("AudioRecorderAPI", " stopRecord myRecorder.stop(); " + e.getMessage());
        }
        try {
            myRecorder.release();
        } catch (Throwable e) {
            Log.d("AudioRecorderAPI", " stopRecord myRecorder.release(); " + e.getMessage());
        }
        cordova.getThreadPool().execute(new Runnable() {
            public void run() {
                Log.d("AudioRecorderAPI", "<-ou- " + outputFile);
                callbackContext.success(outputFile);
            }
        });
    }

}
