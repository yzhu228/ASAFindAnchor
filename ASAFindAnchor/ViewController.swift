//
//  ViewController.swift
//  ASAFindAnchor
//
//  Created by Yu Zhu on 21/3/22.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ASACloudSpatialAnchorSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var mainButton: UIButton!
    
    var cloudSession: ASACloudSpatialAnchorSession? = nil
    // Set this string to the account ID provided for the Azure Spatial Anchors account resource.
    let spatialAnchorsAccountId = "bfa0e9c9-6c5c-41c2-9be2-aa065772a1ed"
    
    // Set this string to the account key provided for the Azure Spatial Anchors account resource.
    let spatialAnchorsAccountKey = "POIWQDGHxlmBP52aXdOpxfixPFUXE2VEnN0Nv8Y4TIc="
    
    // Set this string to the account domain provided for the Azure Spatial Anchors account resource.
    let spatialAnchorsAccountDomain = "australiaeast.mixedreality.azure.com"
    
    var anchorWatcher: ASACloudSpatialAnchorWatcher? = nil
    let foundColor = UIColor.yellow.withAlphaComponent(0.6) // yellow when we successfully located a cloud anchor

    var anchorVisuals = [String : AnchorVisual]()
    var step: DemoStep = .lookForAnchor
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.automaticallyUpdatesLighting = true
        sceneView.debugOptions = .showFeaturePoints
        sceneView.scene = SCNScene()           // Create a new scene and set it on the view
        
        // Main button
        mainButton = addButton()
        mainButton.addTarget(self, action:#selector(mainButtonTap), for: .touchDown)
        mainButton.setTitle("Start locating anchor ...", for: .normal)
        
        layoutButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutButtons()
    }

    // MARK: SCNView delegates
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // per-frame scenekit logic
        // modifications don't go through transaction model
        if let cloudSession = cloudSession {
            cloudSession.processFrame(sceneView.session.currentFrame)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        for visual in anchorVisuals.values {
            if visual.localAnchor == anchor {
                let cube = SCNBox(width: 0.2, height: 0.2, length: 0.2, chamferRadius: 0.0)
                //            let text = SCNText(string: "A cup", extrusionDepth: 0)
                //            text.font = UIFont(name: "Arial", size: 9.0)
                
                //            localAnchor?.transform
                cube.firstMaterial?.diffuse.contents = foundColor
                //            text.firstMaterial?.diffuse.contents = foundColor
                visual.node = SCNNode(geometry: cube)
                //            node?.scale = SCNVector3(0.001, 0.001, 0.001)
                return visual.node
            }
        }
        return nil
    }

    // MARK: AR session deletages
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        print(error)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        if let cloudSession = cloudSession {
            cloudSession.reset()
        }
    }

    // MARK: Session delegate methods

    internal func anchorLocated(_ cloudSpatialAnchorSession: ASACloudSpatialAnchorSession!, _ args: ASAAnchorLocatedEventArgs!) {
        let status = args.status
        print("anchorLocated: status: \(String(describing: status))")
        
        if status == .located {
            if !anchorVisuals.contains(where: {$0.key == args.identifier}) {
                let anchor = args.anchor!
                let visual = AnchorVisual()
                visual.cloudAnchor = anchor
                visual.identifier = anchor.identifier
                visual.localAnchor = anchor.localAnchor
                anchorVisuals[args.identifier] = visual
                sceneView.session.add(anchor: anchor.localAnchor)
            }
        }
    }
    
    internal func locateAnchorsCompleted(_ cloudSpatialAnchorSession: ASACloudSpatialAnchorSession!, _ args: ASALocateAnchorsCompletedEventArgs!) {
    }
    
    internal func error (_ cloudSpatialAnchorSession: ASACloudSpatialAnchorSession!, _ args: ASASessionErrorEventArgs!) {
    }
    
    // MARK: ASA session management functions
    func startLocatingAnchors() {
        let ids: [String] = [
            "22fa0f2e-376b-432b-a80d-5657e5d933c1"
            , "0bdc6e95-cc44-4654-806f-40090c2220bd"
            , "35d65e07-acff-485b-830d-00bc32e09560"
            , "b51a77ad-0cb4-4d2b-a4c7-a19aba260aee"
            , "5efcdcaf-ddce-46ae-847c-3e4a020e6c5f"
        ]
        let criteria = ASAAnchorLocateCriteria()!
        criteria.identifiers = ids
        anchorWatcher = cloudSession!.createWatcher(criteria)
    }
    
    func stopLocatingAnchor() {
        if let anchorWatcher = self.anchorWatcher {
            anchorWatcher.stop()
            self.anchorWatcher = nil
        }
    }

    private func startASASession() {
        cloudSession = ASACloudSpatialAnchorSession()
        cloudSession!.session = sceneView.session
        cloudSession!.logLevel = .information
        cloudSession!.delegate = self
        cloudSession!.configuration.accountId = spatialAnchorsAccountId
        cloudSession!.configuration.accountKey = spatialAnchorsAccountKey
        cloudSession!.configuration.accountDomain = spatialAnchorsAccountDomain
        cloudSession!.start()
    }

    private func stopASASession() {
        if let cloudSession = cloudSession {
            cloudSession.stop()
            cloudSession.dispose()
        }
        cloudSession = nil
        
        clearLocatedAnchors()
    }

    private func clearLocatedAnchors() {
        for visual in anchorVisuals.values {
            visual.node!.removeFromParentNode()
        }
        anchorVisuals.removeAll()
    }
    
    // MARK: UI helper functions
    
    private func layoutButtons() {
        layoutButton(mainButton, top: Double(sceneView.bounds.size.height - 80), lines: Double(1.0))
    }
    
    private func layoutButton(_ button: UIButton, top: Double, lines: Double) {
        let wideSize = sceneView.bounds.size.width - 20.0
        button.frame = CGRect(x: 10.0, y: top, width: Double(wideSize), height: lines * 40)
        if (lines > 1) {
            button.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        }
    }

    func addButton() -> UIButton {
        let result = UIButton(type: .system)
        result.setTitleColor(.black, for: .normal)
        result.setTitleShadowColor(.white, for: .normal)
        result.backgroundColor = UIColor.lightGray.withAlphaComponent(0.6)
        sceneView.addSubview(result)
        return result
    }

    @objc func mainButtonTap(sender: UIButton) {
        switch (step) {
        case .lookForAnchor:
            stopASASession()
            startASASession()
            // We will get a call to onLocateAnchorsCompleted which will move
            // to the next step when the locate operation completes.
            startLocatingAnchors()
            step = .stopWatcher
            mainButton.setTitle("Locating anchors... Tap to stop", for: .normal)
        case .stopWatcher:
            stopLocatingAnchor()
            step = .stopSession
            mainButton.setTitle("Reset ASA Session", for: .normal)
        case .stopSession:
            stopASASession()
            step = .lookForAnchor
            mainButton.setTitle("Start locating anchor", for: .normal)
        default:
            assertionFailure("Demo has somehow entered an invalid state")
        }
    }
}
