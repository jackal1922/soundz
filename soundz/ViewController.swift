//
//  ViewController.swift
//  AJ Player
//
//  Created by 潘則諺 on 2016/6/15.
//  Copyright © 2016年 Jackal Pan. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController,MPMediaPickerControllerDelegate,AVAudioPlayerDelegate {
    
    @IBOutlet weak var musicTitle: MarqueeLabel!
    @IBOutlet weak var musicWave: UIImageView!
    @IBOutlet weak var musicArtist: MarqueeLabel!
    @IBOutlet weak var musicCover: UIImageView!
//    var playButton: PlayPauseButton! = nil
//    var stopButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var volumnSlider: UISlider!
    @IBOutlet weak var startTime: UILabel!
    @IBOutlet weak var timeLine: UISlider!
    @IBOutlet weak var sliderView: UIView!
    @IBOutlet weak var slideValue: UILabel!
    
    @IBOutlet weak var endTime: UILabel!

//    @IBOutlet weak var waveView: WaveformView!
    let mediaPlayer = MPMediaPickerController()
    let musicPlayer = MPMusicPlayerController.applicationMusicPlayer()
    var musicPlay:AVAudioPlayer?
    var selectSong:MPMediaItemCollection! = nil
    var musicVolume = MPVolumeView()
    let audioSession = AVAudioSession()
    var playingTimeTimer : NSTimer?
    
    var hintView: UIView!
    var hintLabel: UILabel!
    
    var checkPlay = 0
    
    var red = UIColor(red: 220.0/255.0, green: 80.0/255.0, blue: 100.0/255.0, alpha: 1.0)

    var actionButton: ActionButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let fullScreenSize = UIScreen.mainScreen().bounds.size
        
        hintLabel = UILabel(frame: CGRectMake(0, 0, 120, 40))
        hintLabel.center = CGPointMake(fullScreenSize.width * 0.5, fullScreenSize.height * 0.5 - 15)
        self.hintLabel.textColor = UIColor.whiteColor()
        self.hintLabel.font = UIFont(name: "Helvetica-Bold", size: 20)
        self.hintLabel.textAlignment = .Center
        self.hintLabel.alpha = 0.7
        self.view.addSubview(self.hintLabel)
        self.hintLabel.hidden = true
        
        volumnSlider.setValue(audioSession.outputVolume, animated: true)
//        let frame = CGRectMake(0 , 0, fullScreenSize.width*0.5, fullScreenSize.height-10)
        let frame = CGRectMake(-28 , 0, fullScreenSize.width-30, fullScreenSize.height*0.35)
        let circularSlider = CircularSlider(frame: frame)
        
        // setup target to watch for value change
        circularSlider.addTarget(self, action: #selector(ViewController.valueChanged(_:)), forControlEvents: UIControlEvents.ValueChanged)
        
        // setup slider defaults
        circularSlider.maximumAngle = 270.0
        circularSlider.unfilledArcLineCap = .Round
        circularSlider.filledArcLineCap = .Round
        circularSlider.handleType = .BigCircle
        circularSlider.currentValue = 10
        circularSlider.lineWidth = 8
        circularSlider.labelDisplacement = -10.0
        circularSlider.innerMarkingLabels = ["0", "20", "40", "60", "80", "100"];
        
        // add to view
        sliderView.addSubview(circularSlider)

        // NOTE: create and set a transform to rotate the arc so the white space is centered at the bottom
        circularSlider.transform = circularSlider.getRotationalTransform()
//----------------------------- [ add marquee effect on the label ] -----------------------------
        musicTitle.tag = 101
        musicTitle.type = .Continuous
        musicTitle.animationCurve = .EaseInOut
//----------------------------- [ add main button ] -----------------------------
//        let gearImage = UIImage(named: "gear_icon.png")!
        let playlistImage = UIImage(named: "playlist_icon.png")!
        let soundzImage = UIImage(named: "soundz.png")!
        let mailImage = UIImage(named: "mail_icon.png")!
  
        let soundz = ActionButtonItem(title: "", image: soundzImage)
        soundz.action = {
            item in print("soundz...")
            self.actionButton.toggleMenu()
        }
        
//        let gear = ActionButtonItem(title: "", image: gearImage)
//        gear.action = {
//            
//            item in print("gear...")
//            self.actionButton.toggleMenu()
//            
//            let sb = UIStoryboard(name: "Main", bundle:nil)
//            let vc = sb.instantiateViewControllerWithIdentifier("gearViewController") as! gearViewController
//            
//            self.presentViewController(vc, animated: false, completion: nil)
//            return
//            
//        }

        let playlist = ActionButtonItem(title: "Playlist", image: playlistImage)
        playlist.action = {
            item in print("soundz...")
            self.actionButton.toggleMenu()
            
            self.mediaPlayer.delegate = self
            self.mediaPlayer.allowsPickingMultipleItems = false
            self.mediaPlayer.showsCloudItems = false
            self.presentViewController(self.mediaPlayer, animated: true, completion: nil)

        }
        
        let mail = ActionButtonItem(title: "Feedback", image: mailImage)
        mail.action = {
            item in print("mail...")
            self.actionButton.toggleMenu()
            let alertView1:UIAlertView = UIAlertView()
            alertView1.alertViewStyle = UIAlertViewStyle.PlainTextInput
//            alertView1.title = "意見回覆"
            alertView1.message = "您的意見是我不斷進化的動力!!"
            alertView1.delegate = nil
            alertView1.addButtonWithTitle("取消")
            alertView1.addButtonWithTitle("送出")
            alertView1.show()
        
        }
        
        actionButton = ActionButton(attachedToView: self.view, items: [mail,playlist])
        actionButton.action = { button in button.toggleMenu() }
        actionButton.setTitle("+", forState: .Normal)
        actionButton.backgroundColor = UIColor(red: 238.0/255.0, green: 130.0/255.0, blue: 34.0/255.0, alpha:1.0)
        
        timeLine.hidden = true
        volumnSlider.hidden = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //----------------------------- [ select the music ] -----------------------------
    func mediaPicker(mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        
        selectSong = mediaItemCollection
        musicPlayer.setQueueWithItemCollection(selectSong)
        musicPlayer.nowPlayingItem = selectSong.items[0] as MPMediaItem
        
        if let url: NSURL = selectSong.items[0].assetURL {
            do {
                // 選到歌曲
                musicPlay = try AVAudioPlayer(contentsOfURL: url)
                musicPlay?.prepareToPlay()
                musicPlay!.enableRate = true
                self.musicTitle.text = selectSong.items[0].title
                self.musicArtist.text = selectSong.items[0].albumArtist! + "( Album : " + selectSong.items[0].albumTitle! + ") "
                
                if selectSong.items[0].artwork != nil {
                    self.musicCover.image = selectSong.items[0].artwork!.imageWithSize(musicCover.bounds.size)
                    self.dismissViewControllerAnimated(true, completion: nil)
                }else{
                    self.musicCover.image = UIImage(named: "no_available.jpg")!
                }
                
                musicCover.frame = self.view.bounds
                musicCover.contentMode = UIViewContentMode.ScaleAspectFit
                
                self.view.addSubview(self.musicCover)
                self.view.sendSubviewToBack(musicCover)
                
                startTime.text = self.formatTimeString(0)
                endTime.text = self.formatTimeString(musicPlay!.duration)
                
                musicCover.alpha = 0.3
                musicPlay!.play()
                self.checkPlay = 0
                playButton.setBackgroundImage(UIImage(named: "pause.jpg"), forState: .Normal)
//                playButton.setTitle("Play", forState: .Normal)
                
                timeLine.hidden = false
                timeLine!.maximumValue = Float(musicPlay!.duration)
                
                
                volumnSlider.hidden = false
            } catch  {
                // 執行發生錯誤
                musicPlay = nil
            }
        } else {
            // url=nil
            musicPlay = nil
        }

    }
    
    func mediaPickerDidCancel(mediaPicker: MPMediaPickerController) {
        self.dismissViewControllerAnimated(true, completion: nil)   //Tap clean then back to view
    }

    //----------------------------- [ play the music ] -----------------------------
    @IBAction func playButton(sender: AnyObject) {
        if checkPlay == 0 && (musicPlay?.url != nil) {
            
            musicPlay!.play()
            
//            waveView.start(&musicPlay!)
//            waveView.randomColor = true
            
            updatePlayingTime()
            playButton.setBackgroundImage(UIImage(named: "pause.jpg"), forState: .Normal)
//            playButton.setTitle("Pause", forState: .Normal)
            checkPlay = 1
            
            if (playingTimeTimer == nil) {
                playingTimeTimer = NSTimer.scheduledTimerWithTimeInterval(
                    1,
                    target: self,
                    selector: #selector(ViewController.updatePlayingTime),
                    userInfo: nil,
                    repeats: true
                )
            }

        }else if checkPlay == 1 {
            musicPlay!.pause()
            checkPlay = 0
            playButton.setBackgroundImage(UIImage(named: "play.jpg"), forState: .Normal)
//            playButton.setTitle("Play", forState: .Normal)
        }
    }
    
    @IBAction func stopButton(sender: AnyObject) {
        if musicPlay?.url != nil {
            musicPlay!.currentTime = 0
            self.updatePlayingTime()
            musicPlay!.stop()
            checkPlay = 0
            playButton.setBackgroundImage(UIImage(named: "play.jpg"), forState: .Normal)
    //        playButton.setTitle("Play", forState: .Normal)
        }
    }
    //----------------------------- [ volume slide ] -----------------------------
    @IBAction func volumeSlider(sender: UISlider) {

        musicPlay!.volume = Float(sender.value)

        hintLabel.hidden = false
        hintLabel.text = "音量：" + String(Int(sender.value*100)) + "%"
        self.view.addSubview(self.hintLabel)
        
    }
    //----------------------------- [ audio perpare set up ] -----------------------------
    func preparePlayerForSound(named sound: String) -> AVAudioPlayer? {
        do {
            if let soundPath = NSBundle.mainBundle().pathForResource(sound, ofType: "mp3") {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                try AVAudioSession.sharedInstance().setActive(true)
                return try AVAudioPlayer(contentsOfURL: NSURL(fileURLWithPath: soundPath))
            } else {
                print("The file '\(sound).mp3' is not available")
            }
        } catch let error as NSError {
            print(error)
        }
        return nil
    }
    //----------------------------- [ time slide ] -----------------------------
    @IBAction func timeSlider(sender: AnyObject) {
        musicPlay!.currentTime = Double(timeLine!.value)
        self.updatePlayingTime()
    }
    //----------------------------- [ time format ] -----------------------------
    func formatTimeString(d : Double) -> String {
        let h : Int = Int(d / 3600)
        let m : Int = Int((d - Double(h) * 3600) / 60)
        let s : Int = Int(d - 3600 * Double(h)) - m * 60
        let str = String(format: "%02d:%02d", m, s)

        return str
    }
    //----------------------------- [ update time ] -----------------------------
    func updatePlayingTime() {
        timeLine!.value = Float((musicPlay?.currentTime)!)
        startTime!.text = self.formatTimeString(musicPlay!.currentTime)
        hintLabelHiden(0)
    }
    
    func hintLabelHiden(value: Int) {
        if value == 0 {
            hintLabel.hidden = true
        }
    }

    func valueChanged(slider: CircularSlider) {
        slideValue.text = "Slow: \(Int(slider.currentValue))%"
        if (musicPlay?.url != nil) {
            if slider.currentValue == 0 {
                musicPlay!.rate = 1
            }else{
                musicPlay!.rate = 1-((slider.currentValue)*0.5/100)
                updatePlayingTime()
            }
        }
    }

}