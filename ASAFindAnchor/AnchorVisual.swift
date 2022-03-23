class AnchorVisual {
    init() {
        node = nil
        identifier = ""
        cloudAnchor = nil
        localAnchor = nil
        name = nil
    }
    
    var name : String? = nil
    var node : SCNNode? = nil
    var identifier : String
    var cloudAnchor : ASACloudSpatialAnchor? = nil
    var localAnchor : ARAnchor? = nil
}
