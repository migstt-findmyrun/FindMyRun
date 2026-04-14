//
//  PolylineDecoder.swift
//  FindMyRun
//

import CoreLocation

enum PolylineDecoder {
    /// Decodes a Google-encoded polyline string into an array of coordinates
    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat: Int = 0
        var lng: Int = 0

        while index < encoded.endIndex {
            lat += decodeNextValue(from: encoded, index: &index)
            lng += decodeNextValue(from: encoded, index: &index)

            coordinates.append(CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            ))
        }

        return coordinates
    }

    private static func decodeNextValue(from encoded: String, index: inout String.Index) -> Int {
        var result = 0
        var shift = 0

        while index < encoded.endIndex {
            let byte = Int(encoded[index].asciiValue!) - 63
            index = encoded.index(after: index)
            result |= (byte & 0x1F) << shift
            shift += 5
            if byte < 0x20 { break }
        }

        return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }
}
