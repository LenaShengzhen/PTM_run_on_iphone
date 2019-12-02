//
//  ViewController.swift
//  RTIScan
//
//  Created by yang yuan on 1/26/19.
//  Copyright © 2019 Yuan Yang. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    
    @IBAction func CameraOn() {
        self.performSegue(withIdentifier: "CameraSegue", sender: self)
    }
    @IBAction func RenderView() {
        self.performSegue(withIdentifier: "RenderSegue", sender: self)
    }
    @IBAction func ImagesView() {
        self.performSegue(withIdentifier: "ImgSegue", sender: self)
    }

}

