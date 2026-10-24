import SwiftUI

/// The Poké Ball drawn with shapes, so it scales from a tab icon to a complication.
struct PokeBallIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let line = max(2, size * 0.09)
            ZStack {
                Circle().fill(.white)
                Circle()
                    .trim(from: 0.5, to: 1)
                    .fill(.red)
                Rectangle()
                    .fill(.black)
                    .frame(height: line)
                Circle()
                    .strokeBorder(.black, lineWidth: line)
                Circle()
                    .fill(.white)
                    .strokeBorder(.black, lineWidth: line)
                    .frame(width: size * 0.34, height: size * 0.34)
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    HStack { PokeBallIcon().frame(width: 60); PokeBallIcon().frame(width: 30) }.padding()
}
