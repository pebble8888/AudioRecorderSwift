//
//  MyAudioRecorder.swift
//  AudioRecorderSwift
//
//  Created by pebble8888 on 2017/09/22.
//  Copyright © 2017年 pebble8888. All rights reserved.
//

import Foundation
import AVFoundation
import AudioUnit

class MyAudioRecorder: NSObject {
    var level: Float  = 0.0
    var frameCount: UInt32 = 0

    private var _audioUnit: AudioUnit?   
    private var _abl: AudioBufferList?
    private let kInputBus: UInt32 =  1
    private let kNumberOfChannels: Int =  1
    
    func start() {
        // AudioSession セットアップ
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(AVAudioSessionCategoryRecord)            
            try audioSession.setActive(true)
        } catch {
        }
        // CoreAudio セットアップ
        var componentDesc:  AudioComponentDescription
            = AudioComponentDescription(
                componentType:          OSType(kAudioUnitType_Output),
                componentSubType:       OSType(kAudioUnitSubType_RemoteIO),
                componentManufacturer:  OSType(kAudioUnitManufacturer_Apple),
                componentFlags:         UInt32(0),
                componentFlagsMask:     UInt32(0) )
        
        let component: AudioComponent! = AudioComponentFindNext(nil, &componentDesc)
        var tau: AudioUnit?
        AudioComponentInstanceNew(component, &tau)
        _audioUnit = tau
        
        guard let au = _audioUnit else { 
            return
        }
        // RemoteIO のマイクを有効にする
        var enable: UInt32 = 1
        AudioUnitSetProperty(au,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input,
                             kInputBus,
                             &enable,
                             UInt32(MemoryLayout<UInt32>.size))

        // マイクから取り出すデータフォーマット
        // 32bit float, linear PCM
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, 
                                      channels: UInt32(kNumberOfChannels)) else {
            return
        }
        
        // RemoteIO のマイクバスから取り出すフォーマットを設定
        AudioUnitSetProperty(au,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output,
                             kInputBus,
                             fmt.streamDescription,
                             UInt32(MemoryLayout<AudioStreamBasicDescription>.size))

        // AudioUnit に録音コールバックを設定
        var inputCallbackStruct
            = AURenderCallbackStruct(inputProc: recordingCallback,
                                     inputProcRefCon:
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        AudioUnitSetProperty(au,
                             AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                             AudioUnitScope(kAudioUnitScope_Global),
                             kInputBus,
                             &inputCallbackStruct,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        // データ取り出し時に使う AudioBufferListの設定
        _abl = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: fmt.channelCount,
                mDataByteSize: fmt.streamDescription.pointee.mBytesPerFrame,
                mData: nil))

        AudioUnitInitialize(au)
        AudioOutputUnitStart(au)
    }
    
    let recordingCallback: AURenderCallback = { (
        inRefCon,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        frameCount,
        ioData ) -> OSStatus in
        
        let audioObject = unsafeBitCast(inRefCon, to: MyAudioRecorder.self)

        if let au = audioObject._audioUnit {
            // マイクから取得したデータを取り出す
            AudioUnitRender(audioObject._audioUnit!,
                                ioActionFlags,
                                inTimeStamp,
                                inBusNumber,
                                frameCount,
                                &audioObject._abl!)
        }
        audioObject.frameCount = frameCount
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(&audioObject._abl!)
        let mBuffers: AudioBuffer = inputDataPtr[0]
        let bufferPointer = UnsafeMutableRawPointer(mBuffers.mData)
        if let bptr = bufferPointer {
            let dataArray = bptr.assumingMemoryBound(to: Float.self)
            // マイクから取得したデータからRMSレベルを計算する
            var sum:Float = 0.0
            if frameCount > 0 {
                for i in 0 ..< Int(frameCount) {
                    sum += (dataArray[i]*dataArray[i])
                }
                audioObject.level = sqrt(sum / Float(frameCount))
            }
        }
        return 0
    }
}
