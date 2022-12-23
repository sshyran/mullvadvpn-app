//
//  ConnectContentView.swift
//  MullvadVPN
//
//  Created by pronebird on 09/03/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import MapKit
import MullvadLogging
import UIKit

private let locationMarkerReuseIdentifier = "location"
private let geoJSONSourceFileName = "countries.geo.json"

final class ConnectContentView: UIView, MKMapViewDelegate {
    enum ActionButton {
        case connect
        case disconnect
        case cancel
        case selectLocation
    }

    private let logger = Logger(label: "ConnectContentView")

    private let mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isUserInteractionEnabled = false
        mapView.accessibilityElementsHidden = true
        return mapView
    }()

    let secureLabel = makeBoldTextLabel(ofSize: 20)
    let cityLabel = makeBoldTextLabel(ofSize: 34)
    let countryLabel = makeBoldTextLabel(ofSize: 34)

    private let activityIndicator: SpinnerActivityIndicatorView = {
        let activityIndicator = SpinnerActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.tintColor = .white
        activityIndicator.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        activityIndicator.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return activityIndicator
    }()

    let locationContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isAccessibilityElement = true
        view.accessibilityTraits = .summaryElement
        return view
    }()

    let connectionPanel: ConnectionPanelView = {
        let view = ConnectionPanelView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let buttonsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = UIMetrics.interButtonSpacing
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    let connectButton: AppButton = {
        let button = AppButton(style: .success)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let cancelButton: AppButton = {
        let button = AppButton(style: .translucentDanger)
        button.accessibilityIdentifier = "CancelButton"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let selectLocationButton: AppButton = {
        let button = AppButton(style: .translucentNeutral)
        button.accessibilityIdentifier = "SelectLocationButton"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    lazy var selectLocationBlurView = TranslucentButtonBlurView(button: selectLocationButton)
    lazy var cancelButtonBlurView = TranslucentButtonBlurView(button: cancelButton)

    let splitDisconnectButton: DisconnectSplitButton = {
        let button = DisconnectSplitButton()
        button.primaryButton.accessibilityIdentifier = "DisconnectButton"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var traitConstraints = [NSLayoutConstraint]()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .primaryColor
        layoutMargins = UIMetrics.contentLayoutMargins
        accessibilityContainerType = .semanticGroup

        setupMapView()
        addSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActionButtons(_ actionButtons: [ActionButton]) {
        let views = actionButtons.map { self.view(forActionButton: $0) }

        setArrangedButtons(views)
    }

    private class func makeBoldTextLabel(ofSize fontSize: CGFloat) -> UILabel {
        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = UIFont.boldSystemFont(ofSize: fontSize)
        textLabel.textColor = .white
        return textLabel
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()

        print("safeAreaInsetsDidChange: \(safeAreaInsets)")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.userInterfaceIdiom != previousTraitCollection?.userInterfaceIdiom {
            updateTraitConstraints()
        }
    }

    private func addSubviews() {
        locationContainerView.addSubview(secureLabel)
        locationContainerView.addSubview(cityLabel)
        locationContainerView.addSubview(countryLabel)

        containerView.addSubview(activityIndicator)
        containerView.addSubview(locationContainerView)
        containerView.addSubview(connectionPanel)
        containerView.addSubview(buttonsStackView)

        addSubview(mapView)
        addSubview(containerView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: topAnchor),
            mapView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: bottomAnchor),

            containerView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            containerView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),

            locationContainerView.topAnchor
                .constraint(greaterThanOrEqualTo: containerView.topAnchor),
            locationContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            locationContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            activityIndicator.centerXAnchor
                .constraint(equalTo: mapView.layoutMarginsGuide.centerXAnchor),
            locationContainerView.topAnchor.constraint(
                equalTo: activityIndicator.bottomAnchor,
                constant: 22
            ),

            secureLabel.topAnchor.constraint(equalTo: locationContainerView.topAnchor),
            secureLabel.leadingAnchor.constraint(equalTo: locationContainerView.leadingAnchor),
            secureLabel.trailingAnchor.constraint(equalTo: locationContainerView.trailingAnchor),

            cityLabel.topAnchor.constraint(equalTo: secureLabel.bottomAnchor, constant: 8),
            cityLabel.leadingAnchor.constraint(equalTo: locationContainerView.leadingAnchor),
            cityLabel.trailingAnchor.constraint(equalTo: locationContainerView.trailingAnchor),

            countryLabel.topAnchor.constraint(equalTo: cityLabel.bottomAnchor, constant: 8),
            countryLabel.leadingAnchor.constraint(equalTo: locationContainerView.leadingAnchor),
            countryLabel.trailingAnchor.constraint(equalTo: locationContainerView.trailingAnchor),
            countryLabel.bottomAnchor.constraint(equalTo: locationContainerView.bottomAnchor),

            connectionPanel.topAnchor.constraint(
                equalTo: locationContainerView.bottomAnchor,
                constant: 8
            ),
            connectionPanel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            connectionPanel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            buttonsStackView.topAnchor.constraint(
                equalTo: connectionPanel.bottomAnchor,
                constant: 24
            ),
            buttonsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            buttonsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        updateTraitConstraints()
        addDebugGuideViews()
    }

    private func addDebugGuideViews() {
        let centerX = UIView()
        centerX.translatesAutoresizingMaskIntoConstraints = false
        centerX.backgroundColor = .red
        centerX.isUserInteractionEnabled = false

        let centerY = UIView()
        centerY.translatesAutoresizingMaskIntoConstraints = false
        centerY.backgroundColor = .red
        centerY.isUserInteractionEnabled = false

        addSubview(centerX)
        addSubview(centerY)

        NSLayoutConstraint.activate([
            centerY.widthAnchor.constraint(equalToConstant: 1),
            centerY.centerXAnchor.constraint(equalTo: mapView.layoutMarginsGuide.centerXAnchor),
            centerY.topAnchor.constraint(equalTo: topAnchor),
            centerY.bottomAnchor.constraint(equalTo: bottomAnchor),

            centerX.heightAnchor.constraint(equalToConstant: 1),
            centerX.centerYAnchor.constraint(equalTo: mapView.layoutMarginsGuide.centerYAnchor),
            centerX.leadingAnchor.constraint(equalTo: leadingAnchor),
            centerX.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func updateTraitConstraints() {
        var layoutConstraints = [NSLayoutConstraint]()

        switch traitCollection.userInterfaceIdiom {
        case .pad:
            // Max container width is 70% width of iPad in portrait mode
            let maxWidth = min(
                UIScreen.main.nativeBounds.width * 0.7,
                UIMetrics.maximumSplitViewContentContainerWidth
            )

            layoutConstraints.append(contentsOf: [
                containerView.trailingAnchor.constraint(
                    lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor
                ),
                containerView.widthAnchor.constraint(equalToConstant: maxWidth)
                    .withPriority(.defaultHigh),
            ])

        case .phone:
            layoutConstraints.append(
                containerView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor)
            )

        default:
            break
        }

        removeConstraints(traitConstraints)
        traitConstraints = layoutConstraints
        NSLayoutConstraint.activate(layoutConstraints)
    }

    private func setArrangedButtons(_ newButtons: [UIView]) {
        buttonsStackView.arrangedSubviews.forEach { button in
            if !newButtons.contains(button) {
                buttonsStackView.removeArrangedSubview(button)
                button.removeFromSuperview()
            }
        }

        newButtons.forEach { button in
            buttonsStackView.addArrangedSubview(button)
        }
    }

    private func view(forActionButton actionButton: ActionButton) -> UIView {
        switch actionButton {
        case .connect:
            return connectButton
        case .disconnect:
            return splitDisconnectButton
        case .cancel:
            return cancelButtonBlurView
        case .selectLocation:
            return selectLocationBlurView
        }
    }

    // MARK: - Map view manipulations

    private var targetRegion: MKCoordinateRegion?
    private let locationMarker = MKPointAnnotation()

    func updateMap(from tunnelState: TunnelState, animated: Bool) {
        logger.debug("updateMap() tunnelState = \(tunnelState)")

        switch tunnelState {
        case let .connecting(tunnelRelay):
            removeLocationMarker()
            activityIndicator.startAnimating()

            if let tunnelRelay = tunnelRelay {
                setLocation(coordinate: tunnelRelay.location.geoCoordinate, animated: animated)
            } else {
                unsetLocation(animated: animated)
            }

        case let .reconnecting(tunnelRelay):
            removeLocationMarker()
            activityIndicator.startAnimating()

            setLocation(coordinate: tunnelRelay.location.geoCoordinate, animated: animated)

        case let .connected(tunnelRelay):
            let coordinate = tunnelRelay.location.geoCoordinate

            setLocation(coordinate: coordinate, animated: animated) { [weak self] in
                self?.mapDidFinishAnimatingToConnectedState(coordinate: coordinate)
            }

        case .pendingReconnect:
            removeLocationMarker()
            activityIndicator.startAnimating()

        case .waitingForConnectivity:
            removeLocationMarker()
            activityIndicator.stopAnimating()

        case .disconnected, .disconnecting:
            removeLocationMarker()
            activityIndicator.stopAnimating()

            unsetLocation(animated: animated)
        }
    }

    private func mapDidFinishAnimatingToConnectedState(coordinate: CLLocationCoordinate2D) {
        logger.debug("mapDidFinishAnimatingToConnectedState")
        activityIndicator.stopAnimating()
        addLocationMarker(coordinate: coordinate)
    }

    private func setupMapView() {
        mapView.delegate = self
        mapView.register(
            MKAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: locationMarkerReuseIdentifier
        )

        // Use dark style for the map to dim the map grid
        mapView.overrideUserInterfaceStyle = .dark

        addTileOverlay()
        loadGeoJSONData()
    }

    private func addTileOverlay() {
        // Use `nil` for template URL to make sure that Apple maps do not load tiles from remote.
        let tileOverlay = MKTileOverlay(urlTemplate: nil)

        // Replace the default map tiles
        tileOverlay.canReplaceMapContent = true

        mapView.addOverlay(tileOverlay, level: .aboveLabels)
    }

    private func loadGeoJSONData() {
        guard let fileURL = Bundle.main.url(
            forResource: geoJSONSourceFileName,
            withExtension: nil
        ) else {
            logger.debug("Failed to locate \(geoJSONSourceFileName) in main bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let overlays = try GeoJSON.decodeGeoJSON(data)

            mapView.addOverlays(overlays, level: .aboveLabels)
        } catch {
            logger.error(error: error, message: "Failed to load geojson.")
        }
    }

    // MARK: - Map location manipulations

    private func setLocation(
        coordinate: CLLocationCoordinate2D,
        animated: Bool,
        animationDidEnd: (() -> Void)? = nil
    ) {
        let sourceRegion = makeRegionForLocationAt(coordinate)
        let offsetRegion = region(sourceRegion, withCenterMatching: activityIndicator)

        setMapRegion(offsetRegion, animated: animated, animationDidEnd: animationDidEnd)
    }

    private func unsetLocation(animated: Bool) {
        let span = MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 90)
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let region = mapView.regionThatFits(MKCoordinateRegion(center: coordinate, span: span))

        setMapRegion(region, animated: animated, animationDidEnd: nil)
    }

    // MARK: - Location marker

    private func addLocationMarker(coordinate: CLLocationCoordinate2D) {
        locationMarker.coordinate = coordinate
        mapView.addAnnotation(locationMarker)
    }

    private func removeLocationMarker() {
        mapView.removeAnnotation(locationMarker)
    }

    // MARK: - Map region animations

    private var isAnimatingMap = false
    private var mapRegionAnimationDidEnd: (() -> Void)?

    private func setMapRegion(
        _ region: MKCoordinateRegion,
        animated: Bool,
        animationDidEnd: (() -> Void)?
    ) {
        if let targetRegion = targetRegion, targetRegion.isApproximatelyEqualTo(region) {
            if isAnimatingMap {
                logger.debug("Update animationDidEnd to \(animationDidEnd)")

                mapRegionAnimationDidEnd = animationDidEnd
            } else {
                logger.debug("Call animationDidEnd right away.")
                mapRegionAnimationDidEnd = nil
                animationDidEnd?()
            }
        } else {
            targetRegion = region

            let handler = {
                self.mapRegionAnimationDidEnd = animationDidEnd

                if self.mapView.region.isApproximatelyEqualTo(region) {
                    self.logger.debug("[1] mapView.region is approx. equal to our region...")
                }

                self.mapView.setRegion(region, animated: animated)
            }

            if isAnimatingMap {
                logger.debug("Chain switch to next region. animationDidEnd = \(animationDidEnd)")

                mapRegionAnimationDidEnd = {
                    self.logger
                        .debug(
                            "Call chanined switch to next region. animationDidEnd = \(animationDidEnd)"
                        )
                    handler()
                }
            } else {
                mapRegionAnimationDidEnd = animationDidEnd

                logger.debug("isAnimatingMap = true. animationDidEnd = \(animationDidEnd)")

                mapView.setRegion(region, animated: animated)
            }
        }
    }

    private func mapRegionWillChange(animated: Bool) {
        guard !isAnimatingMap else { return }

        isAnimatingMap = true
    }

    private func mapRegionDidChange(animated: Bool) {
        guard isAnimatingMap else { return }

        isAnimatingMap = false

        let animationDidEnd = mapRegionAnimationDidEnd
        mapRegionAnimationDidEnd = nil

        logger.debug("isAnimatingMap = false, calling \(animationDidEnd)")

        animationDidEnd?()
    }

    private func makeRegionForLocationAt(_ center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let span = MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        let region = MKCoordinateRegion(center: center, span: span)

        return mapView.regionThatFits(region)
    }

    private func makeRegionForUnsetLocation() -> MKCoordinateRegion {
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let span = MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 90)
        let region = MKCoordinateRegion(center: coordinate, span: span)

        return mapView.regionThatFits(region)
    }

    private func region(
        _ region: MKCoordinateRegion,
        withCenterMatching alignmentView: UIView
    ) -> MKCoordinateRegion {
        // Map view center lies within layout margins frame.
        let mapViewLayoutFrame = mapView.layoutMarginsGuide.layoutFrame

        // MKMapView.convert(_:toRectTo:) returns CGRect scaled to the zoom level derived from
        // currently set region.
        // Calculate the ratio that we can use to translate the rect within its own coordinate
        // system before converting it into MKCoordinateRegion.
        let newZoomLevel = mapViewLayoutFrame.width / region.span.longitudeDelta
        let currentZoomLevel = mapViewLayoutFrame.width / mapView.region.span.longitudeDelta
        let zoomDelta = currentZoomLevel / newZoomLevel

        let imageRect = alignmentView.convert(alignmentView.bounds, to: mapView)
        let horizontalOffset = (mapViewLayoutFrame.midX - imageRect.midX) * zoomDelta
        let verticalOffset = (mapViewLayoutFrame.midY - imageRect.midY) * zoomDelta

        let regionRect = mapView.convert(region, toRectTo: mapView)
        let offsetRegionRect = regionRect.offsetBy(dx: horizontalOffset, dy: verticalOffset)
        let offsetRegion = mapView.convert(offsetRegionRect, toRegionFrom: mapView)

        return offsetRegion
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = .primaryColor
            renderer.strokeColor = .secondaryColor
            renderer.lineWidth = 1
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        if let tileOverlay = overlay as? MKTileOverlay {
            return CustomOverlayRenderer(overlay: tileOverlay)
        }

        return MKOverlayRenderer()
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation === locationMarker else { return nil }

        let view = mapView.dequeueReusableAnnotationView(
            withIdentifier: locationMarkerReuseIdentifier,
            for: annotation
        )
        view.isDraggable = false
        view.canShowCallout = false
        view.image = UIImage(named: "LocationMarkerSecure")

        return view
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        mapRegionWillChange(animated: animated)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        mapRegionDidChange(animated: animated)
    }
}

private extension MKCoordinateRegion {
    func isApproximatelyEqualTo(_ other: MKCoordinateRegion) -> Bool {
        return center.latitude.roundToDecimal(3) == other.center.latitude.roundToDecimal(3) &&
            center.longitude.roundToDecimal(3) == other.center.longitude.roundToDecimal(3) &&
            span.latitudeDelta.roundToDecimal(3) == other.span.latitudeDelta.roundToDecimal(3) &&
            span.longitudeDelta.roundToDecimal(3) == other.span.longitudeDelta.roundToDecimal(3)
    }
}

private extension Double {
    func roundToDecimal(_ fractionDigits: Int) -> Double {
        let multiplier = pow(10, Double(fractionDigits))
        return Darwin.round(self * multiplier) / multiplier
    }
}
