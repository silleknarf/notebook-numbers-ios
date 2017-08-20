//
//  ViewController.swift
//  notebooknumbers
//
//  Created by Frank Ellis on 22/07/2017.
//  Copyright © 2017 silleknarf. All rights reserved.
//

import GameKit
import WebKit
import UIKit

class ViewController:
    UIViewController,
    GKGameCenterControllerDelegate,
    WKScriptMessageHandler,
    UIWebViewDelegate,
    WKNavigationDelegate {
    
    private var webView: WKWebView?;
    
    let LOGGED_IN_EVENT = "SYSTEM:LEADERBOARDS:LOGGED_IN";
    let LOGGED_OUT_EVENT = "SYSTEM:LEADERBOARDS:LOGGED_OUT";
    let CHECK_LOGIN_EVENT = "SYSTEM:SWIFT:CHECK_LOGIN";
    let UPDATE_LEADERBOARD_EVENT = "SYSTEM:SWIFT:UPDATE_LEADERBOARDS";
    let OPEN_LEADERBOARD_EVENT = "SYSTEM:SWIFT:OPEN_LEADERBOARDS";
    
    var gcEnabled = Bool() // Check if the user has Game Center enabled
    var gcDefaultLeaderBoard = String() // Check the default leaderboardID
    
    var score = 0
    var isLoggedIn = false;
    var isUIWebViewLoaded = false;
    
    let LEADERBOARD_ID = "com.silleknarf.notebooknumbers.highscores"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let defaults = UserDefaults.standard
        let hasLoadedWKWebView = defaults.bool(forKey: "hasLoadedWKWebView");
        
        // If we have loaded the WKWebView before we can start right up
        if (hasLoadedWKWebView) {
            loadWKWebView(uiWebViewLoadStorage: nil)
            
        // First time we need to load the old type of webview and get any configuration
        } else {
            loadUIWebView()
        }
    }
    
    // Load the old style UIWebView so we can pull the local storage out (sad we have to do this)
    func loadUIWebView() {
        let uiWebView = UIWebView()
        view = uiWebView;
        let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "notebook-numbers")
        let htmlUrl = URL(fileURLWithPath: htmlPath!, isDirectory: false)
        uiWebView.loadRequest(URLRequest(url: htmlUrl));
        uiWebView.delegate = self;
    }
    
    func loadWKWebView(uiWebViewLoadStorage: [String: Any]?) {
        
        let contentController = WKUserContentController()
        // Set up our JS integration
        contentController.add(self, name: "swift")
        
        // If we've passed in a dict of local storage items 
        // let's turn this into some JS to start up with
        if uiWebViewLoadStorage != nil {
            let loadLoadStorage = getLoadLocalStorageUserScript(
                uiWebViewLoadStorage: uiWebViewLoadStorage!)
            contentController.addUserScript(loadLoadStorage)
        }
        
        // Full screen and add our script
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
        view = webView
        
        // Load the notebook numbers html
        let htmlPath = Bundle.main.path(
            forResource: "index",
            ofType: "html",
            inDirectory: "notebook-numbers")
        let htmlUrl = URL(fileURLWithPath: htmlPath!, isDirectory: false)
        webView!.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl)
    }
    
    // WKWebView has loaded
    func webView(_ didFinishwebView: WKWebView, didFinish navigation: WKNavigation!) {
        // Call the GC authentication controller
        authenticateLocalPlayer()
        
        // Next time we run we can straight up load the WKWebView
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasLoadedWKWebView");
    }
    
    // Turn a dictionary of JS things into a script which sets up localStorage
    func getLoadLocalStorageUserScript(uiWebViewLoadStorage: [String: Any]) -> WKUserScript {
        var loadLocalStorageScript = "";
        for (key, value) in uiWebViewLoadStorage {
            // Do some horrible JS string munging
            let strValue = value as! String;
            let setLocalStorageItemJs = "localStorage.setItem('\(key)','\(strValue)');"
            loadLocalStorageScript += setLocalStorageItemJs;
        }
        let userScript = WKUserScript(source: loadLocalStorageScript,
                                      injectionTime: WKUserScriptInjectionTime.atDocumentStart,
                                      forMainFrameOnly: true)
        return userScript;
    }
    
    // When the old-style UIWebView is loaded then we can boot up the new WKWebView
    // with our original localStorage data
    func webViewDidFinishLoad(_ uiWebView: UIWebView) {
        if (!isUIWebViewLoaded &&
            uiWebView.stringByEvaluatingJavaScript(from: "document.readyState") == "complete") {
            isUIWebViewLoaded = true;
            let localStorage = uiWebView.stringByEvaluatingJavaScript(from: "JSON.stringify(localStorage)")
            if let dictionary = localStorage?.toJSON() as? [String: Any] {
                loadWKWebView(uiWebViewLoadStorage: dictionary)
            } else {
                loadWKWebView(uiWebViewLoadStorage: nil)
            }
        }
    }
    
    func runJavaScriptEvent(event: String) {
        let event = "eventManager.vent.trigger('\(event)')"
        self.webView!.evaluateJavaScript(event)
    }
    
    func checkLogInStatus() {
        if (self.isLoggedIn) {
            runJavaScriptEvent(event: LOGGED_IN_EVENT)
        } else {
            runJavaScriptEvent(event: LOGGED_OUT_EVENT)
        }
    }
    
    // Handle JS events
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
}

extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}

