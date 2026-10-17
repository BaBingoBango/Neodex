import SwiftUI

/// The scanner's model, described the way the dataset card describes the data.
struct RecognizerCard: View {
    @State private var manifest = ClassifierManifest.load()

    var body: some View {
        if let manifest {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scanner Model \(manifest.version)")
                        .font(.body.weight(.semibold))
                    Text("Recognises \(manifest.classes.count.formatted()) Pokémon and forms, trained on \(manifest.trainingImages.formatted()) images: official artwork, 3D renders, animated sprites and trading-card illustrations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let accuracy = manifest.validationAccuracy {
                        Text("\(Int((accuracy * 100).rounded()))% accurate on \(manifest.validationImages.formatted()) trading cards it never saw.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        } else {
            Label("This build has no scanner model.", systemImage: "eye.slash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
