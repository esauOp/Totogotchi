import Foundation

/// Keeps a `TaskStore` change handler alive. Releasing it stops the callbacks.
public final class TaskStoreObservation {
    private var cancel: (() -> Void)?

    init(cancel: @escaping () -> Void) {
        self.cancel = cancel
    }

    deinit { cancel?() }

    /// Stops the callbacks now rather than when this token is released.
    public func invalidate() {
        cancel?()
        cancel = nil
    }
}
