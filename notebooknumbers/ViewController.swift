//
//  ViewController.swift
//  notebooknumbers
//
//  Created by Frank Ellis on 22/07/2017.
//  Copyright © 2017 silleknarf. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Load the notebook numbers html
        let localfilePath = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "notebook-numbers");
        let myRequest = URLRequest(url: localfilePath!);
        webView.loadRequest(myRequest);
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        // Make full screen
        webView.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height);
    }
}

