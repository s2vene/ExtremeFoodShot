import SwiftUI

struct FullScreenPhotoItem: Identifiable {
    let id: UUID
    let image: UIImage
}

struct FullScreenPhotoView: View {
    let items: [FullScreenPhotoItem]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int
    @State private var scale = 1.0
    @State private var lastScale = 1.0

    init(items: [FullScreenPhotoItem], initialID: UUID) {
        self.items = items
        let initialIndex = items.firstIndex { $0.id == initialID } ?? 0
        _selectedIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(items.indices, id: \.self) { index in
                    Image(uiImage: items[index].image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(index == selectedIndex ? scale : 1)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    guard index == selectedIndex else { return }
                                    scale = min(max(lastScale * value, 1), 5)
                                }
                                .onEnded { _ in
                                    guard index == selectedIndex else { return }
                                    lastScale = scale
                                }
                        )
                        .onTapGesture(count: 2) {
                            guard index == selectedIndex else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scale = scale > 1 ? 1 : 2
                                lastScale = scale
                            }
                        }
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selectedIndex) {
                scale = 1
                lastScale = 1
            }

            if items.count > 1 {
                Text("\(selectedIndex + 1)/\(items.count)")
                    .font(.fsBody)
                    .foregroundStyle(Color.fsWhite)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.fsNavy.opacity(0.5), in: Capsule())
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .statusBarHidden()
    }
}

#if DEBUG
#Preview("사진 크게 보기") {
    FullScreenPhotoView(
        items: [
            FullScreenPhotoItem(id: UUID(), image: UIImage(systemName: "photo")!),
            FullScreenPhotoItem(id: UUID(), image: UIImage(systemName: "camera")!)
        ],
        initialID: UUID()
    )
}
#endif
