//
//  ScreenRecorder.swift
//  ScreenRecordSampler
//
//  Created by tanaka.takaaki on 2016/12/09.
//  Copyright © 2016年 tanaka.takaaki. All rights reserved.
//

import AVFoundation
import Foundation
import UIKit

final class ScreenRecorder {
    
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var writerInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var displayLink: CADisplayLink?
    
    private var firstFrameTime: CFAbsoluteTime?
    private var startTimestamp: CFTimeInterval?
    
    private var queue: DispatchQueue?
    //private var backgroundTask: UIBackgroundTaskIdentifier?
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidEnterBackground(notification:)), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillEnterForeground(notification:)), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        queue = DispatchQueue(label: "jo.co.classmethod")
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private let frameInterval = 2
    private let autosaveDuration = 600
    
    
    func startRecording() {
        
        setupAssetWriter(with: self.outputFileURL())
        
        displayLink = CADisplayLink(target: self, selector: #selector(self.captureFrame(displayLink:)))
        displayLink?.add(to: RunLoop.current, forMode: .commonModes)
        
//        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(captureFrame:)];
//        self.displayLink.frameInterval = self.frameInterval;
//        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        
        
    }
    
    func stopRecording() {
        
        displayLink?.invalidate()
        
        startTimestamp = 0
        
        queue?.sync { [weak self] in
            
            if self?.writer?.status != .completed && self?.writer?.status != .unknown {
                self?.writerInput?.markAsFinished()
            }
            self?.writer?.finishWriting(completionHandler: { [weak self] in
                self?.restartRecordingIfNeeded()
            })
        }
    }

    func restartRecordingIfNeeded() {
    
    }
    
    private func outputFileURL() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        
        let documentsDirectory = paths[0]
        
        let path = documentsDirectory + "/mov.mov"
        
        return URL(fileURLWithPath: path)
    }
    
    private func setupAssetWriter(with outputURL: URL) {
        writer = try! AVAssetWriter(url: outputURL, fileType: AVFileTypeQuickTimeMovie)
        
        let mainScreen = UIScreen.main
        let size = mainScreen.bounds.size
        
        let outputSettings: [String : Any] = [AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : size.width, AVVideoHeightKey : size.height]
        writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
        writerInput?.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : kCVPixelFormatType_32ARGB]
        
        writerInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput!, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        writer?.add(writerInput!)
        
        firstFrameTime = CFAbsoluteTimeGetCurrent()
        
        writer?.startWriting()
        writer?.startSession(atSourceTime: kCMTimeZero)
    }
    
    @objc internal func applicationDidEnterBackground(notification: NSNotification) {
    
    }
    
    @objc internal func applicationWillEnterForeground(notification: NSNotification) {
        
    }
    
    @objc internal func captureFrame(displayLink: CADisplayLink) {
        queue?.sync { [weak self] in
            if (self?.writerInput?.isReadyForMoreMediaData)! {
                var status: CVReturn = kCVReturnSuccess
                
                var buffer: CVPixelBuffer? = nil
               // var backingData: CFType
                
                var screenshot: UIImage? = nil
                
                DispatchQueue.main.sync {
                    screenshot = self?.screenshot()
                }
                
                guard let image = screenshot?.cgImage else { return }
                
                let dataProvider = image.dataProvider
                
                
                let data = dataProvider?.data
                let backingData = CFDataCreateMutableCopy(kCFAllocatorDefault, CFDataGetLength(data), data)
                
                
                let bytePtr: UnsafePointer<UInt8> = CFDataGetBytePtr(backingData)
                
                status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                                      image.width,
                                                      image.height,
                                                      kCVPixelFormatType_32BGRA,
                                                      bytePtr,
                                                      image.bytesPerRow,
                                                      nil,
                                                      nil,
                                                      nil,
                                                      &buffer)
                
                //NSParameterAssert(status == kCVReturnSuccess && buffer)
                
            }
        }
    }
    
    func screenshot() -> UIImage? {
        let mainScreen = UIScreen.main
        
        let imageSize = mainScreen.bounds.size
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let mainWindows = UIApplication.shared.windows.filter { window -> Bool in
            window.screen == mainScreen
        }
        
        mainWindows.forEach { window in
            context.saveGState()
            context.translateBy(x: window.center.x, y: window.center.y)
            context.concatenate(window.transform)
            context.translateBy(x: -window.bounds.size.width * window.layer.anchorPoint.x, y: -window.bounds.size.height * window.layer.anchorPoint.y)
            window.layer.presentation()?.render(in: context)
            context.restoreGState()
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return image
    }
}
