import SwiftUI
import UIKit

/// 用 UILongPressGestureRecognizer 实现可靠的「按住说话、松手上屏」。
/// 主 App 听写试场与键盘扩展共用。
struct HoldToTalkButton<Content: View>: View {
    var onPressBegan: () -> Void
    var onPressEnded: () -> Void
    var onPressCancelled: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        HoldToTalkRepresentable(
            onPressBegan: onPressBegan,
            onPressEnded: onPressEnded,
            onPressCancelled: onPressCancelled,
            content: content
        )
    }
}

private struct HoldToTalkRepresentable<Content: View>: UIViewRepresentable {
    var onPressBegan: () -> Void
    var onPressEnded: () -> Void
    var onPressCancelled: () -> Void
    let content: Content

    func makeUIView(context: Context) -> HoldUIView {
        let view = HoldUIView()
        view.onPressBegan = onPressBegan
        view.onPressEnded = onPressEnded
        view.onPressCancelled = onPressCancelled

        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.isUserInteractionEnabled = false
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hosting.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hosting.view.widthAnchor.constraint(equalTo: view.widthAnchor),
            hosting.view.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        context.coordinator.hosting = hosting
        return view
    }

    func updateUIView(_ uiView: HoldUIView, context: Context) {
        uiView.onPressBegan = onPressBegan
        uiView.onPressEnded = onPressEnded
        uiView.onPressCancelled = onPressCancelled
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var hosting: UIHostingController<AnyView>?
    }

    final class HoldUIView: UIView {
        var onPressBegan: (() -> Void)?
        var onPressEnded: (() -> Void)?
        var onPressCancelled: (() -> Void)?
        private var isPressed = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = true
            let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
            gesture.minimumPressDuration = 0.12
            gesture.cancelsTouchesInView = false
            addGestureRecognizer(gesture)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func handleGesture(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                isPressed = true
                onPressBegan?()
            case .ended:
                guard isPressed else { return }
                isPressed = false
                onPressEnded?()
            case .cancelled, .failed:
                guard isPressed else { return }
                isPressed = false
                onPressCancelled?()
            default:
                break
            }
        }
    }
}
