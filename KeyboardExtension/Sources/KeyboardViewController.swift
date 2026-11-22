import UIKit
import SwiftUI
import TypeFreeCore

/// 键盘扩展入口（NSExtensionPrincipalClass）。
@objc(KeyboardViewController)
public final class KeyboardViewController: UIInputViewController {

    private let model = KeyboardModel()
    private var hostingController: UIHostingController<AnyView>?
    private var heightConstraint: NSLayoutConstraint?

    public override func viewDidLoad() {
        super.viewDidLoad()

        model.proxy = textDocumentProxy
        model.onDismiss = { [weak self] in self?.dismissKeyboard() }
        model.onNextInputMode = { [weak self] in self?.advanceToNextInputMode() }
        model.hasFullAccess = hasFullAccess

        let root = KeyboardRootView(model: model)
        let hosting = UIHostingController(rootView: AnyView(root))
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController = hosting

        inputView?.allowsSelfSizing = true
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.refreshContext()
        model.hasFullAccess = hasFullAccess
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installHeightConstraint()
    }

    public override func textDidChange(_ textInput: UITextInput?) {
        // 宿主输入框变化（v0.1 不做场景感知，Phase 2 接入）。
    }

    private func installHeightConstraint() {
        let keyboardHeight: CGFloat = 288
        let bottomInset = view.safeAreaInsets.bottom
        let constant = keyboardHeight + bottomInset

        if let existing = heightConstraint {
            existing.constant = constant
            return
        }
        let constraint = view.heightAnchor.constraint(equalToConstant: constant)
        constraint.priority = .required
        constraint.isActive = true
        heightConstraint = constraint
        view.setNeedsLayout()
    }
}
