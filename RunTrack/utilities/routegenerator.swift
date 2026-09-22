import Foundation
import MapKit
import CoreLocation

/// Génère un parcours en boucle approximatif d'une distance donnée, au départ d'un point donné,
/// en s'appuyant sur les itinéraires piétons réels de MapKit (suit les routes/chemins existants).
enum RouteGenerator {

    static func generateLoop(from start: CLLocationCoordinate2D, distanceKm: Double) async -> [CLLocationCoordinate2D]? {
        // On vise un point de mi-parcours ("turnaround"), puis on relie l'aller et le retour
        // en choisissant, parmi les itinéraires proposés par MapKit, la paire qui se recouvre
        // le moins — pour obtenir une vraie boucle plutôt qu'un aller-retour sur le même chemin.
        let turnaroundDistanceMeters = (distanceKm * 1000) / 2.4

        guard turnaroundDistanceMeters > 50 else { return nil }

        let bearingsToTry: [Double] = [0, 90, 180, 270, 45, 135, 225, 315].map { $0 * .pi / 180 }

        var bestResult: [CLLocationCoordinate2D]?
        var bestOverlap = Double.greatestFiniteMagnitude

        for bearing in bearingsToTry {
            let turnaround = destination(from: start, distanceMeters: turnaroundDistanceMeters, bearingRadians: bearing)

            guard let outboundRoutes = await walkingRoutes(from: start, to: turnaround),
                  let returnRoutes = await walkingRoutes(from: turnaround, to: start) else {
                continue
            }

            guard let (outbound, inbound, overlap) = bestPair(outboundRoutes: outboundRoutes, returnRoutes: returnRoutes) else {
                continue
            }

            if overlap < bestOverlap {
                bestOverlap = overlap
                var coordinates = outbound
                coordinates.append(contentsOf: inbound)
                bestResult = coordinates
            }

            // Boucle déjà bien distincte à l'aller et au retour : inutile de continuer à chercher.
            if bestOverlap < 0.25 {
                break
            }
        }

        return bestResult
    }

    /// Demande un itinéraire piéton, avec ses éventuelles alternatives.
    private static func walkingRoutes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async -> [[CLLocationCoordinate2D]]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            guard !response.routes.isEmpty else { return nil }
            return response.routes.map { $0.polyline.coordinates }
        } catch {
            return nil
        }
    }

    /// Choisit, parmi toutes les combinaisons aller/retour, celle qui se recouvre le moins.
    private static func bestPair(
        outboundRoutes: [[CLLocationCoordinate2D]],
        returnRoutes: [[CLLocationCoordinate2D]]
    ) -> (outbound: [CLLocationCoordinate2D], inbound: [CLLocationCoordinate2D], overlap: Double)? {
        var best: (outbound: [CLLocationCoordinate2D], inbound: [CLLocationCoordinate2D], overlap: Double)?

        for outbound in outboundRoutes {
            for inbound in returnRoutes {
                let overlap = overlapRatio(outbound, inbound)
                if best == nil || overlap < best!.overlap {
                    best = (outbound, inbound, overlap)
                }
            }
        }

        return best
    }

    /// Estime à quel point deux tracés se superposent (0 = itinéraires bien distincts, 1 = quasi identiques).
    private static func overlapRatio(_ a: [CLLocationCoordinate2D], _ b: [CLLocationCoordinate2D]) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 1 }

        let bLocations = b.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let sampleStep = max(1, a.count / 20)
        var closeCount = 0
        var sampleCount = 0

        for index in stride(from: 0, to: a.count, by: sampleStep) {
            let point = CLLocation(latitude: a[index].latitude, longitude: a[index].longitude)
            let minDistance = bLocations.map { $0.distance(from: point) }.min() ?? .greatestFiniteMagnitude
            if minDistance < 40 {
                closeCount += 1
            }
            sampleCount += 1
        }

        guard sampleCount > 0 else { return 1 }
        return Double(closeCount) / Double(sampleCount)
    }

    /// Calcule un point à une distance et un cap donnés depuis un point de départ (formule géodésique simple).
    private static func destination(from start: CLLocationCoordinate2D, distanceMeters: Double, bearingRadians: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let angularDistance = distanceMeters / earthRadius

        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearingRadians))
        let lon2 = lon1 + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
