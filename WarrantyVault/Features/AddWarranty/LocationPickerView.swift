import SwiftUI
import MapKit
import CoreLocation


struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let initialCoordinate: CLLocationCoordinate2D?
    let onPicked: (CLLocationCoordinate2D) -> Void

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    @State private var addressLine: String = ""

    private static let fallback = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    init(initial: CLLocationCoordinate2D?, onPicked: @escaping (CLLocationCoordinate2D) -> Void) {
        self.initialCoordinate = initial
        self.onPicked = onPicked
        let start = initial ?? Self.fallback
        _center = State(initialValue: start)
        _position = State(initialValue: .region(
            MKCoordinateRegion(
                center: start,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position)
                    .mapStyle(.standard(elevation: .realistic))
                    .onMapCameraChange(frequency: .onEnd) { ctx in
                        center = ctx.region.center
                        Task { await reverseGeocode(center) }
                    }


                VStack(spacing: 0) {
                    Image(systemName: "mappin")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppColors.brandBlue)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)

                    Color.clear.frame(height: 30)
                }
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    addressBar
                }
            }
            .navigationTitle("Pick location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use this") {
                        onPicked(center)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task { await reverseGeocode(center) }
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill").foregroundStyle(AppColors.brandBlue)
            Text(addressLine.isEmpty ? "Drag the map to pick a spot" : addressLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16).padding(.bottom, 16)
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        let geo = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let placemark = try? await geo.reverseGeocodeLocation(location).first {
            addressLine = [placemark.name, placemark.locality, placemark.country]
                .compactMap { $0 }
                .joined(separator: ", ")
        }
    }
}
