// see this API's for alternative match making
//https://developer.apple.com/documentation/gamekit/gkmatchmaker/1520930-queryactivity
//https://developer.apple.com/documentation/gamekit/gkmatchmaker/1520518-finishmatchmaking
//https://developer.apple.com/documentation/gamekit/gkmatchmaker/1520561-addplayerstomatch


//
//  GCConnection.swift
//  GCConnection
//
//  Created by Viktor Braun on 02.01.2019.
//  Copyright © 2019 Viktor Braun - Software Development. All rights reserved.
//

import Foundation
import UIKit
import GameKit

public enum AuthStatus{
    case undef
    case ok(localPlayer : GKLocalPlayer)
    case loginRequired(viewController : UIViewController)
    case error(err : Error)
    case loginCancelled
}

public protocol AuthHandler{
    func handle(connection : GCConnection, authStatusChanged : AuthStatus)
}

public class GCConnection{
    
    private var _currentMatch : MatchBase? = nil
    
    private static var _default = GCConnection()
    public static var shared : GCConnection{
        get{
            return ._default
        }
    }
    
    public var authHandler : AuthHandler?{
        didSet{
            DispatchQueue.main.async {
                self.authHandler?.handle(connection: self, authStatusChanged: self.authStatus)
            }
        }
    }
    
    public var authenticated : Bool{
        switch self.authStatus {
        case .ok( _):
            return true
        default:
            return false
        }
    }
    
    public var authStatus : AuthStatus = .undef
    
    public var activeMatch : MatchBase?{
        get{
            guard let cm = _currentMatch else{
                return nil
            }
            
            switch cm.state {
            case .disconnected(_):
                _currentMatch = nil
                return _currentMatch
            default:
                // none
                return _currentMatch
            }
            
        }
    }
    
    fileprivate func log(_ items : Any...){
        let itemString = items.map { String(describing: $0) }.joined(separator: " ")
        print("GCConn: " + itemString)
    }
    
    public func authenticate(){
        let localPlayer = GKLocalPlayer.local
        
        localPlayer.authenticateHandler = { (controller, error) in
            
            if let error = error{
                if let gkErr = error as? GKError{
                    if gkErr.code == GKError.Code.cancelled {
                        self.authStatus = .loginCancelled
                    } else{
                        self.authStatus = .error(err: error)
                    }
                }
                else{
                    self.authStatus = .error(err: error)
                }
            }
            else if localPlayer.isAuthenticated{
                self.authStatus = .ok(localPlayer: localPlayer)
            }
            else if let controller = controller {
                self.authStatus = .loginRequired(viewController: controller)
            }
            else{
                self.authStatus = .undef
            }
            
            DispatchQueue.main.async {
                self.authHandler?.handle(connection: self, authStatusChanged: self.authStatus)
            }
            
        }
    }
    
    func findRealtimeMatch(withVC : ViewController, minPlayers: Int, maxPlayers: Int) throws -> RealtimeMatch{
        if activeMatch != nil {
            throw createError(withMessage: "there is already an active match")
        }
        
        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        request.playerGroup = 1
//        request.inviteMessage = "hi"
        
        let result = RealtimeMatch(rq: request)
        result.findWithViewController(parentVC: withVC)
        
        _currentMatch = result
        
        return result
    }
    
    func findMatch(minPlayers: Int, maxPlayers: Int) throws -> RealtimeMatch{
        let defaultTimeout : DispatchTime = .now() + .seconds(60)
        let result = try findMatch(minPlayers: minPlayers, maxPlayers: maxPlayers, withTimeout: defaultTimeout )
        
        return result
    }
    
    func findMatch(minPlayers: Int, maxPlayers: Int, withTimeout : DispatchTime) throws -> RealtimeMatch{
        if activeMatch != nil {
            throw createError(withMessage: "there is already an active match")
        }
        
        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        request.playerGroup = 1
//        request.inviteMessage = "hi"
        
        let result = RealtimeMatch(rq: request, matchMaker: GKMatchmaker.shared())
        result.find(timeout: withTimeout)
        
        _currentMatch = result
        
        return result
    }
    
    func findTurnbasedMatch(minPlayers: Int, maxPlayers: Int, withTimeout : DispatchTime)throws -> TurnBasedMatch{

        if activeMatch != nil {
            throw createError(withMessage: "there is already an active match")
        }

        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        
        

        let result = TurnBasedMatch(rq: request)
        result.find(timeout: withTimeout)

        _currentMatch = result

        return result


    }
}
public enum DisconnectedReason{
    case matchEmpty
    case matchMakingTimeout
    case cancel
    case error
}
public enum MatchState{
    case pending
    case connected
    case disconnected(reason : DisconnectedReason)
}
public protocol MatchHandler{
    func handle(_ error : Error)
    func handle(_ state : MatchState)
    func handle(data : Data, fromPlayer : GKPlayer)
    func handle(playerDisconnected : GKPlayer)
}

public class TurnBasedMatch : MatchBase, GKLocalPlayerListener{
    
    fileprivate var _match : GKTurnBasedMatch?
    
    required init(rq : GKMatchRequest){
        super.init(rq: rq)
    }
    
    func find(timeout : DispatchTime){
        
        DispatchQueue.main.asyncAfter(deadline: timeout, execute: {
            switch self.state{
            case .pending:
                self.cancelInternal(reason: .matchMakingTimeout)
            default:
                return
            }
        })
        
        self.state = .pending
        // see this answer:
        // https://stackoverflow.com/questions/44864598/gkturnbasedmatch-after-creating-joining-a-match-prints-2nd-player-status-as-matc
        
        // we have to start a turn to make this match available to others :-(
        GKTurnBasedMatch.find(for: _request, withCompletionHandler:{ (match, err) in
            if let err = err {
                self.error(err)
            }
            else if let match = match {
                self._match = match
                print("GCConn: player-0", match.participants[0].player?.displayName)
                print("GCConn: player-1", match.participants[1].player?.displayName)
                GKLocalPlayer.local.register(self)
            }
            else{
                self.error(createError(withMessage: "received unexpected nil match"))
            }
        })
    }
    
    public func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
        print("GCConn: didRequestMatchWithRecipients")
        self.updateState(.connected)
    }
    public func player(_ player: GKPlayer, didRequestMatchWithOtherPlayers playersToInvite: [GKPlayer]) {
        print("GCConn: didRequestMatchWithOtherPlayers")
    }
    public func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        print("GCConn: didAccept invide")
    }
    
    
    public func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
        guard match.matchID == _match?.matchID else {return}
        
        DispatchQueue.main.async {
            self.handler?.handle(playerDisconnected: player)
        }
    }
    
    public func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        guard match.matchID == _match?.matchID else {return}

        self.updateState(.disconnected(reason: .matchEmpty))
    }
    
    public func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        guard match.matchID == _match?.matchID else {return}
        match.loadMatchData { data, error in
            if let error = error{
                self.error(error)
            }
            else if let data = data{
                DispatchQueue.main.async {
                    self.handler?.handle(data: data, fromPlayer: player)
                }
            }
            else{
                DispatchQueue.main.async {
                    self.handler?.handle(data: Data(), fromPlayer: player)
                }
            }
        }
    }
    
    fileprivate override func cancelInternal(reason : DisconnectedReason){
        if let match = self._match {
            self._match = nil
            match.remove(completionHandler: {error in})
            self.updateState(.disconnected(reason: reason))
        }
        
        
    }
}


public class RealtimeMatch : MatchBase, GKMatchDelegate, GKMatchmakerViewControllerDelegate{
    
    fileprivate var _matchMaker : GKMatchmaker
    fileprivate var _match : GKMatch?
    fileprivate var _vc : GKMatchmakerViewController?
    
    public var players : [GKPlayer] {
        get{
            guard let p = self._match?.players else {
                return []
            }
            
            return p
        }
    }
    
    
    required init(rq : GKMatchRequest, matchMaker : GKMatchmaker){
        self._matchMaker = matchMaker
        super.init(rq: rq)
    }
    
    required init(rq: GKMatchRequest) {
        self._matchMaker = GKMatchmaker.shared()
        super.init(rq: rq)
    }
    
    fileprivate func findWithViewController(parentVC : ViewController){
        self.state = .pending
        
        self._vc = GKMatchmakerViewController(matchRequest: self._request)!
        self._vc!.matchmakerDelegate = self
        parentVC.present(self._vc!, animated: true, completion: nil)
    }
    
    public func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        self.cancelInternal(reason: .cancel)
        self._vc?.dismiss(animated: true, completion: nil)
    }
    
    public func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        self.error(error)
        self._vc?.dismiss(animated: true, completion: nil)
    }
    
    public func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        self._vc?.dismiss(animated: true, completion: nil)
        self._match = match
        self._match!.delegate = self
        self.updateState(.connected)
        print("GCConn: received match", match.players, match.expectedPlayerCount)
    }
    
    public func matchmakerViewController(_ viewController: GKMatchmakerViewController, hostedPlayerDidAccept player: GKPlayer) {
        print("GCConn: matchmakerViewController.hostedPlayerDidAccept")
    }
    
    public func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFindHostedPlayers players: [GKPlayer]) {
        print("GCConn: matchmakerViewController.didFindHostedPlayers")
    }
    
    fileprivate func find(timeout : DispatchTime) {
//        DispatchQueue.main.asyncAfter(deadline: timeout, execute: {
//            switch self.state{
//            case .pending:
//                self.cancelInternal(reason: .matchMakingTimeout)
//            default:
//                return
//            }
//        })
        
        self.state = .pending
        
        self._matchMaker.findMatch(for: self._request) { (match, err) in
            
            if let err = err {
                self.error(err)
            }
            else if let match = match {
                self._match = match
                self._match!.delegate = self
                print("GCConn: received match", match.players, match.expectedPlayerCount)
            }
            else{
                self.error(createError(withMessage: "received unexpected nil match"))
            }
        }
    }
    
    fileprivate func initPlayers() {
        guard let match = self._match else{
            return
        }
        
        let playerIDs = match.players.map { $0.playerID }
        GKPlayer.loadPlayers(forIdentifiers: playerIDs) { (players, error) in
            if let error = error {
                self.error(error)
                return
            }
            
            self.updateState(.connected)
            GKMatchmaker.shared().finishMatchmaking(for: match)
        }
    }
    
    public func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool{
        print("GCConn: shouldReinviteDisconnectedPlayer")
        return true
    }
    
    public func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState){
        guard self._match == match else {
            return
        }
        
        switch state {
        case .connected where self._match != nil && match.expectedPlayerCount == 0:
            initPlayers()
        case .disconnected:
            DispatchQueue.main.async {
                self.handler?.handle(playerDisconnected: player)
            }
            
            if match.players.count == 0{
                self.cancelInternal(reason: .matchEmpty)
            }
        default:
            break
        }
    }
    
    public func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        DispatchQueue.main.async {
            self.handler?.handle(data: data, fromPlayer: player)
        }
    }
    
    public func match(_ match: GKMatch, didFailWithError error: Error?) {
        guard self._match == match else {
            return
        }
        
        guard let error = error else{
            return
        }
        
        self.error(error)
    }
    
    public func broadCast(data : Data, withMode : GKMatch.SendDataMode) throws{
        guard let match = self._match else {
            return
        }
        
        switch self.state {
        case .connected:
            try match.sendData(toAllPlayers: data, with: withMode)
        default:
            return
        }
        
        
    }
    
    fileprivate override func cancelInternal(reason : DisconnectedReason){
        self._matchMaker.cancel()
        if let match = self._match {
            self._match = nil
            match.disconnect()
        }
        
        self.updateState(.disconnected(reason: reason))
    }

    
}

fileprivate func createError(withMessage: String) -> Error{
    let err = NSError(domain: "GCConnection", code: 2, userInfo: [ NSLocalizedDescriptionKey: "received unexpected nil match"])
    return err
}



public class MatchBase : NSObject{
    fileprivate var _request : GKMatchRequest
    public var state : MatchState = .pending
    
    public var handler : MatchHandler? {
        didSet{
            DispatchQueue.main.async {
                self.handler?.handle(self.state)
            }
        }
    }
    
    required init(rq : GKMatchRequest){
        self._request = rq
        super.init()
    }
    
    fileprivate func updateState(_ newState : MatchState){
        self.state = newState
        DispatchQueue.main.async {
            self.handler?.handle(self.state)
        }
    }
    
    fileprivate func error(_ err : Error){
        if err is GKError && (err as! GKError).code == GKError.Code.cancelled{
            return
        }
        
        DispatchQueue.main.async {
            self.handler?.handle(err)
        }
        self.cancelInternal(reason: .error)
    }
    
    fileprivate func cancelInternal(reason : DisconnectedReason){
        preconditionFailure("This method must be overridden")
    }
    
    
    public func cancel(){
        cancelInternal(reason: .cancel)
    }
}
