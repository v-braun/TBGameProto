//
//  ViewController.swift
//  TBGameProto
//
//  Created by Viktor Braun on 26.08.2019.
//  Copyright © 2019 Viktor Braun - Software Development. All rights reserved.
//

import UIKit
import PMSuperButton
import CDAlertView
import GameKit

class ViewController: UIViewController, MatchHandler {

    @IBOutlet weak var _startBtn: PMSuperButton!
    
    
    override func viewDidLoad() {
        
        
        super.viewDidLoad()
        
        
        
        _startBtn.touchUpInside(action: {
            self.startTouched();
        })
        
        // Do any additional setup after loading the view.
    }
    
    func showMsg(txt : String, _ type: CDAlertViewType){
        let alert = CDAlertView(title: "NOPE!", message: txt, type: type)
        
        let doneAction = CDAlertViewAction(title: "Got it! 💪")
        alert.add(action: doneAction)
        
        
        alert.show()
    }
    
    func checkAuthentication() -> Bool{
        switch GCConnection.shared.authStatus {
        case .undef:
            // not authenticated
            showMsg(txt: "You are not authetnicated, please go to settings and activate GameCenter for this app", .warning)
            return false
        case .loginCancelled:
            // login canccelled 🙅‍♀️
            showMsg(txt: "You cancelled the GameCenter authentication, please go to settings and activate GameCenter for this app", .warning)
            return false
        case .error(let err):
            // auth err
            showMsg(txt: "GC Err: \(err.localizedDescription)", .error)
            return false
        case .loginRequired(let viewController):
            // login required
            // show present ciewController - it is the GC login view
            self.present(viewController, animated: true, completion: nil)
            return false
        case .ok(_):
            // authenticated 🥳
            return true
        }
    }
//    4mcqxeg8pR9
    
    func startTouched(){
        if !checkAuthentication(){
            return
        }
        
        
    }
    
    func createMatch(){
        let match = try! GCConnection.shared.findMatch(minPlayers: 2, maxPlayers: 2, withTimeout: .now() + .seconds(30))
        
        match.handler = self
        
        
    }
    
    func handle(_ error : Error){
        showMsg(txt: "match err: \(error)", .error)
    }
    func handle(_ state : MatchState){
        print("match", "new state", state)
    }
    func handle(data : Data, fromPlayer : GKPlayer){
        print("match", "new data", "player", fromPlayer.displayName)
    }
    func handle(playerDisconnected : GKPlayer){
        print("match", "player disconnect", playerDisconnected.displayName)
    }


}

