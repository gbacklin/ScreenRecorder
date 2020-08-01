//
//  ViewController.swift
//  ScreenRecorder
//
//  Created by Gene Backlin on 7/31/20.
//

import UIKit
import ReplayKit
import AVKit

class ViewController: UIViewController, RPPreviewViewControllerDelegate {
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var colorPicker: UISegmentedControl!
    @IBOutlet var colorDisplay: UIView!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var micToggle: UISwitch!
    
    let recorder = RPScreenRecorder.shared()
    private var isRecording = false
    var videoOutputURL: URL?
    var videoWriter: AVAssetWriter?
    var videoWriterInput: AVAssetWriterInput?
    var audioMicInput: AVAssetWriterInput?
    var sampleBuffer: CMSampleBuffer?
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        recordButton.layer.cornerRadius = 32.5
    }
    
    func viewReset() {
        micToggle.isEnabled = true
        statusLabel.text = "Ready to Record"
        statusLabel.textColor = UIColor.black
        recordButton.backgroundColor = UIColor.green
    }
    
    @IBAction func colors(sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            colorDisplay.backgroundColor = UIColor.red
        case 1:
            colorDisplay.backgroundColor = UIColor.blue
        case 2:
            colorDisplay.backgroundColor = UIColor.orange
        case 3:
            colorDisplay.backgroundColor = UIColor.green
        default:
            colorDisplay.backgroundColor = UIColor.red
        }
    }
    
    @IBAction func recordButtonTapped() {
        if !isRecording {
            statusLabel.text = "Recording..."
           startRecording()
        } else {
            statusLabel.text = "Stopped recording"
            stopRecording()
        }
    }
    
    func startRecording() {
        guard recorder.isAvailable else {
            print("Recording is not available at this time.")
            return
        }
        
        if micToggle.isOn {
            recorder.isMicrophoneEnabled = true
        } else {
            recorder.isMicrophoneEnabled = false
        }
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let url: URL = URL(fileURLWithPath: documentsPath.appendingPathComponent("Videos_Temp.mp4"))
        videoOutputURL = url
        
        //Check the file does not already exist by deleting it if it does
        do {
            try FileManager.default.removeItem(at: url)
        } catch {}
        
        do {
            try videoWriter = AVAssetWriter(outputURL: url, fileType: AVFileType.mp4)
        } catch let writerError as NSError {
            debugPrint("Error opening video file", writerError)
            videoWriter = nil
            return
        }
        
        //Create the video settings
        let videoSettings: [String : Any] = [
            AVVideoCodecKey  : AVVideoCodecType.h264,
            AVVideoWidthKey  : self.view.frame.width,  //Replace as you need
            AVVideoHeightKey : self.view.frame.height   //Replace as you need
        ]
        
        let audioSettings = [
          AVFormatIDKey : kAudioFormatMPEG4AAC,
          AVNumberOfChannelsKey : 2,
          AVSampleRateKey : 44100.0,
          AVEncoderBitRateKey: 192000
          ] as [String : Any]

        //Create the asset writer input object whihc is actually used to write out the video
        //with the video settings we have created
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        audioMicInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)

        videoWriter!.add(videoWriterInput!)
        videoWriter!.add(audioMicInput!)

        print("Started Recording Successfully")
        self.micToggle.isEnabled = false
        self.recordButton.backgroundColor = UIColor.red
        self.statusLabel.textColor = UIColor.red
        
        self.isRecording = true
        
        recorder.startCapture(handler: {[weak self] (buffer, type, error) in
            guard error == nil else {
                //Handle error
                debugPrint("Error starting capture");
                return;
            }
            
            if CMSampleBufferDataIsReady(buffer) {
                self!.sampleBuffer = buffer
                DispatchQueue.main.async {
                    switch type {
                    case .video:
                        //self!.statusLabel.text = "writing video"
                        if self!.videoWriter?.status == AVAssetWriter.Status.unknown {
                            if ((self!.videoWriter?.startWriting) != nil) {
                                self!.statusLabel.text = "Starting writing"
                                self!.videoWriter!.startWriting()
                                self!.videoWriter!.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
                            }
                        }
                        if self!.videoWriter?.status == AVAssetWriter.Status.writing {
                            if self!.videoWriterInput!.isReadyForMoreMediaData == true {
                                if self!.videoWriterInput!.append(buffer) == false {
                                    self!.statusLabel.text = " we have a problem writing video"
                                }
                            }
                        }
                    case .audioApp:
                        //self!.statusLabel.text = "writing audio"
                        break
                    case .audioMic:
                        if self!.audioMicInput!.isReadyForMoreMediaData {
                            debugPrint("audioMic data added")
                            self!.audioMicInput!.append(buffer)
                        }
                        break
                    @unknown default:
                        self!.statusLabel.text = "capture unknown type: \(type)"
                    }
                }
            }
        }) { (error) in
            if error != nil {
                debugPrint(error!.localizedDescription)
            }
        }
        
    }
    
    func stopRecording() {
        recorder.stopCapture {[weak self] (error) in
            DispatchQueue.main.async {
                self!.videoWriterInput!.markAsFinished();
                self!.videoWriter!.finishWriting {
                    DispatchQueue.main.async {
                        if self!.videoWriter!.status == AVAssetWriter.Status.writing {
                            if self!.videoWriterInput!.isReadyForMoreMediaData {
                                if self!.videoWriterInput!.append(self!.sampleBuffer!) == false {
                                    self!.statusLabel.text = "problem writing video"
                                }
                            }
                        }

                        debugPrint("FileWritten to: \(self!.videoOutputURL!)")
                        self!.isRecording = false
                        self!.viewReset()
                        self!.playVideo()
                    }
                }
            }
        }
    }
    
    private func playVideo() {
        guard let path = videoOutputURL else {
            debugPrint("video.m4v not found")
            return
        }
        
        let player = AVPlayer(url: path)
        let playerController = AVPlayerViewController()
        playerController.view.frame = self.view.bounds;
        playerController.player = player
        present(playerController, animated: true) {
            player.play()
        }
    }
    
}

