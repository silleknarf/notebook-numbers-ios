//
//  ViewController.swift
//  notebooknumbers
//
//  Created by Frank Ellis on 22/07/2017.
//  Copyright © 2017 silleknarf. All rights reserved.
//

import GameKit
import WebKit

class ViewController: UIViewController, GKGameCenterControllerDelegate, WKScriptMessageHandler {
    
    private var webView: WKWebView?;
    
    let LOGGED_IN_EVENT = "SYSTEM:LEADERBOARDS:LOGGED_IN";
    let LOGGED_OUT_EVENT = "SYSTEM:LEADERBOARDS:LOGGED_OUT";
    let CHECK_LOGIN_EVENT = "SYSTEM:SWIFT:CHECK_LOGIN";
    let UPDATE_LEADERBOARD_EVENT = "SYSTEM:SWIFT:UPDATE_LEADERBOARDS";
    let OPEN_LEADERBOARD_EVENT = "SYSTEM:SWIFT:OPEN_LEADERBOARDS";
    
    /* Variables */
    var gcEnabled = Bool() // Check if the user has Game Center enabled
    var gcDefaultLeaderBoard = String() // Check the default leaderboardID
    
    var score = 0
    var isLoggedIn = false;
    
    // IMPORTANT: replace the red string below with your own Leaderboard ID (the one you've set in iTunes Connect)
    let LEADERBOARD_ID = "com.silleknarf.notebooknumbers.highscores"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let contentController = WKUserContentController()
        contentController.add(self, name: "swift")
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        webView = WKWebView(frame: .zero, configuration: config)
        view = webView
        
        // Call the GC authentication controller
        authenticateLocalPlayer()
        
        // Load the notebook numbers html
        let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "notebook-numbers")
        let htmlUrl = URL(fileURLWithPath: htmlPath!, isDirectory: false)
        webView!.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl)
    }
    
    func runJavaScriptEvent(event: String) {
        let event = "eventManager.vent.trigger('" + event + "')"
        self.webView!.evaluateJavaScript(event)
    }
    
    func checkLogInStatus() {
        if (self.isLoggedIn) {
            runJavaScriptEvent(event: LOGGED_IN_EVENT)
        } else {
            runJavaScriptEvent(event: LOGGED_OUT_EVENT)
        }
    }
    
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage) {
        
        let body = message.body
        if let dict = body as? Dictionary<String, AnyObject> {
            let event = dict["event"] as? String;
            if (event == CHECK_LOGIN_EVENT) {
                checkLogInStatus();
            } else if (event == OPEN_LEADERBOARD_EVENT) {
                openLeaderboardinGC()
            } else if (event == UPDATE_LEADERBOARD_EVENT) {
                let score = dict["params"] as! Int64
                updateLeaderboardInGC(score: score)
            }
        }
    }
    
    // MARK: - AUTHENTICATE LOCAL PLAYER
    func authenticateLocalPlayer() {
        let localPlayer: GKLocalPlayer = GKLocalPlayer.localPlayer()
        
        localPlayer.authenticateHandler = {(ViewController, error) -> Void in
            if((ViewController) != nil) {
                // 1. Show login if player is not logged in
                self.present(ViewController!, animated: true, completion: nil)
                self.runJavaScriptEvent(event: self.LOGGED_OUT_EVENT)
                self.isLoggedIn = true
            } else if (localPlayer.isAuthenticated) {
                // 2. Player is already authenticated & logged in, load game center
                self.gcEnabled = true
                
                // Get the default leaderboard ID
                localPlayer.loadDefaultLeaderboardIdentifier(completionHandler: { (leaderboardIdentifer, error) in
                    if error != nil {
                        print(error!)
                    } else {
                        self.gcDefaultLeaderBoard = leaderboardIdentifer!
                    }
                })
                self.runJavaScriptEvent(event: self.LOGGED_IN_EVENT);
                self.isLoggedIn = true;
            } else {
                // 3. Game center is not enabled on the users device
                self.gcEnabled = false
                print("Local player could not be authenticated!")
                self.runJavaScriptEvent(event: self.LOGGED_OUT_EVENT)
                self.isLoggedIn = false
            }
        }
    }
    
    // MARK: - ADD 10 POINTS TO THE SCORE AND SUBMIT THE UPDATED SCORE TO GAME CENTER
    @IBAction func updateLeaderboardInGC(score: Int64) {
        if (!self.isLoggedIn) {
            return
        }
        // Submit score to GC leaderboard
        let bestScoreInt = GKScore(leaderboardIdentifier: LEADERBOARD_ID)
        bestScoreInt.value = Int64(score)
        GKScore.report([bestScoreInt]) { (error) in
            if error != nil {
                print(error!.localizedDescription)
            } else {
                print("Best Score submitted to your Leaderboard!")
            }
        }
    }
    
    // MARK: - OPEN GAME CENTER LEADERBOARD
    @IBAction func openLeaderboardinGC() {
        let gcVC = GKGameCenterViewController()
        gcVC.gameCenterDelegate = self
        gcVC.viewState = .leaderboards
        gcVC.leaderboardIdentifier = LEADERBOARD_ID
        present(gcVC, animated: true, completion: nil)
    }
    
    // Delegate to dismiss the GC controller
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        // Make full screen
        webView!.frame = CGRect(
            x: 0,
            y: 0,
            width: self.view.frame.size.width,
            height: self.view.frame.size.height)
    }
}

