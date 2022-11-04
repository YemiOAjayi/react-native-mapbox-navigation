import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import Foundation

// // adapted from https://pspdfkit.com/blog/2017/native-view-controllers-and-react-native/ and https://github.com/mslabenyak/react-native-mapbox-navigation/blob/master/ios/Mapbox/MapboxNavigationView.swift
extension UIView {
  var parentViewController: UIViewController? {
    var parentResponder: UIResponder? = self
    while parentResponder != nil {
      parentResponder = parentResponder!.next
      if let viewController = parentResponder as? UIViewController {
        return viewController
      }
    }
    return nil
  }
}

class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
  weak var navViewController: NavigationViewController?
  var embedded: Bool
  var embedding: Bool
  
  @objc var origin: NSArray = [] {
    didSet { setNeedsLayout() }
  }
  
  @objc var destination: NSArray = [] {
    didSet { setNeedsLayout() }
  }
  @objc var route: NSString = ""
  @objc var shouldSimulateRoute: Bool = false
  @objc var showsEndOfRouteFeedback: Bool = false
  @objc var hideStatusView: Bool = false
  @objc var mute: Bool = false
  
  @objc var onLocationChange: RCTDirectEventBlock?
  @objc var onRouteProgressChange: RCTDirectEventBlock?
  @objc var onError: RCTDirectEventBlock?
  @objc var onCancelNavigation: RCTDirectEventBlock?
  @objc var onArrive: RCTDirectEventBlock?
  
  override init(frame: CGRect) {
    self.embedded = false
    self.embedding = false
    super.init(frame: frame)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if (navViewController == nil && !embedding && !embedded) {
      embed()
    } else {
      navViewController?.view.frame = bounds
    }
  }
  
  override func removeFromSuperview() {
    super.removeFromSuperview()
    // cleanup and teardown any existing resources
    self.navViewController?.removeFromParent()
  }
  
  private func embed() {
    guard origin.count == 2 && destination.count == 2 else { return }
    
    embedding = true
      
    // ToDo: Add support for additional waypoints. Route API doesn't currently support this.
    let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: origin[1] as! CLLocationDegrees, longitude: origin[0] as! CLLocationDegrees))
    let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees))

    let options = NavigationRouteOptions(waypoints: [originWaypoint, destinationWaypoint], profileIdentifier: .automobileAvoidingTraffic)
      
    let decoder = JSONDecoder()
    decoder.userInfo[.options] = options
    let decodedRoute: Route? = try? decoder.decode(Route.self, from: route.data(using: String.Encoding.utf8.rawValue)!)

    guard let parentVC = self.parentViewController else {
      return
    }
    if let route = decodedRoute {
        let routeResponse = RouteResponse(httpResponse: nil, routes: [route], waypoints: [originWaypoint, destinationWaypoint],  options: .route(options), credentials: Directions.shared.credentials)
        
        let navigationService = MapboxNavigationService(routeResponse: routeResponse, routeIndex: 0, routeOptions: options, simulating: self.shouldSimulateRoute ? .always : .never)
        
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        let vc = NavigationViewController(for: routeResponse, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)

        vc.showsEndOfRouteFeedback = self.showsEndOfRouteFeedback
        StatusView.appearance().isHidden = self.hideStatusView

        NavigationSettings.shared.voiceMuted = self.mute;
        
        vc.delegate = self
      
        parentVC.addChild(vc)
        self.addSubview(vc.view)
        vc.view.frame = self.bounds
        vc.didMove(toParent: parentVC)
        self.navViewController = vc 
    }
    
    self.embedding = false
    self.embedded = true
  }
  
  func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
    onLocationChange?(["longitude": location.coordinate.longitude, "latitude": location.coordinate.latitude])
    onRouteProgressChange?(["distanceTraveled": progress.distanceTraveled,
                            "durationRemaining": progress.durationRemaining,
                            "fractionTraveled": progress.fractionTraveled,
                            "distanceRemaining": progress.distanceRemaining])
  }
  
  func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
    if (!canceled) {
      return;
    }
    onCancelNavigation?(["message": ""]);
  }
  
  func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
    onArrive?(["message": ""]);
    return true;
  }
}
