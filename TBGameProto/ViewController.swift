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
    
    private var _match : RealtimeMatch? = nil
    
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
        
        if _match == nil {
            self.createMatch()
        }
        else{
            let msg = "hi".data(using: .utf8)!
            try? _match?.broadCast(data: msg, withMode: .reliable)
        }
        
        
    }
    
    func createMatch(){
        _match = try! GCConnection.shared.findMatch(minPlayers: 2, maxPlayers: 2, withTimeout: .now() + .seconds(90))
//        _match = try! GCConnection.shared.findRealtimeMatch(withVC: self, minPlayers: 2, maxPlayers: 2)
        
//        let match = try! GCConnection.shared.findTurnbasedMatch(minPlayers: 2, maxPlayers: 2, withTimeout: .now() + .seconds(30))
        _match?.handler = self
        self._startBtn.isHidden = true
    }
    
    func handle(_ error : Error){
        showMsg(txt: "match err: \(error)", .error)
    }
    func handle(_ state : MatchState){
        print("GCConn: match", "new state", state)
        switch state {
        case .disconnected(_):
            self._startBtn.isHidden = false
        case .connected:
            self._startBtn.isHidden = false
            self._startBtn.setTitle("send hi", for: .normal)
        default:
            return
        }
        
    }
    func handle(data : Data, fromPlayer : GKPlayer){
        print("GCConn: match", "new data", "player", fromPlayer.displayName)
        let msg = String(data: data, encoding: .utf8)!
        showMsg(txt: msg, .notification)
    }
    func handle(playerDisconnected : GKPlayer){
        print("GCConn: match", "player disconnect", playerDisconnected.displayName)
        
    }


}

