@_spi(Backends) import SwiftCrossUI
import WinUI

// Many force tries are required for the WinUI backend but we don't really want them
// anywhere else so just disable the lint rule at a file level.
// swiftlint:disable force_try

// MARK: TextField

extension WinUIBackend {
    public func createTextField() -> Widget {
        let textField = TextBox()
        // An edit reaches the change action from `TextChanging`, which WinUI raises synchronously
        // with `Text` already holding the new text. `TextChanged` is raised later, asynchronously
        // (after the new text is rendered), so a view update that ran between an edit and its
        // `TextChanged` would find the binding one edit behind the box, and `TextField`'s commit would
        // write the old text back over the edit. GtkBackend's `changed` and AppKitBackend's
        // `textDidChange` are synchronous in the same way. `TextChanged` still reports any change
        // `TextChanging` did not.
        textField.textChanging.addHandler { [weak internalState, weak textField] _, _ in
            guard let internalState, let textField else { return }
            internalState.reportEdit(of: ObjectIdentifier(textField), text: textField.text)
        }
        textField.textChanged.addHandler { [weak internalState, weak textField] _, _ in
            guard let internalState, let textField else { return }
            internalState.reportEdit(of: ObjectIdentifier(textField), text: textField.text)
        }
        textField.keyUp.addHandler { [weak internalState] _, event in
            guard let internalState else { return }

            if event?.key == .enter {
                internalState.textFieldSubmitActions[ObjectIdentifier(textField)]?()
            }
        }
        return textField
    }

    public func updateTextField(
        _ textField: Widget,
        placeholder: String,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        let textField = textField as! TextBox
        textField.placeholderText = placeholder
        internalState.textFieldChangeActions[ObjectIdentifier(textField)] = onChange
        internalState.textFieldSubmitActions[ObjectIdentifier(textField)] = onSubmit
        environment.apply(to: textField)

        updateInputScope(of: textField, textContentType: environment.textContentType)
    }

    public func setContent(ofTextField textField: Widget, to content: String) {
        let textField = textField as! TextBox
        // Not an edit: the `TextChanging` and `TextChanged` this write raises are not reported.
        internalState.textFieldReportedTexts[ObjectIdentifier(textField)] = content
        textField.text = content
    }

    public func getContent(ofTextField textField: Widget) -> String {
        (textField as! TextBox).text
    }
}

// MARK: SecureField

extension WinUIBackend {
    public func createSecureField() -> Widget {
        let secureField = PasswordBox()
        // Edits are reported from `PasswordChanging`, raised synchronously with `Password` already
        // new, as a text field's are from `TextChanging` (see `createTextField`); `PasswordChanged`
        // reports any change `PasswordChanging` did not.
        secureField.passwordChanging.addHandler { [weak internalState, weak secureField] _, _ in
            guard let internalState, let secureField else { return }
            internalState.reportEdit(of: ObjectIdentifier(secureField), text: secureField.password)
        }
        secureField.passwordChanged.addHandler { [weak internalState, weak secureField] _, _ in
            guard let internalState, let secureField else { return }
            internalState.reportEdit(of: ObjectIdentifier(secureField), text: secureField.password)
        }
        secureField.keyUp.addHandler { [weak internalState] _, event in
            guard let internalState else { return }

            if event?.key == .enter {
                internalState.textFieldSubmitActions[ObjectIdentifier(secureField)]?()
            }
        }
        return secureField
    }

    public func updateSecureField(
        _ secureField: Widget,
        placeholder: String,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        let secureField = secureField as! PasswordBox
        secureField.placeholderText = placeholder
        internalState.textFieldChangeActions[ObjectIdentifier(secureField)] = onChange
        internalState.textFieldSubmitActions[ObjectIdentifier(secureField)] = onSubmit
        environment.apply(to: secureField)

        updateInputScope(of: secureField, textContentType: environment.textContentType)
    }

    public func setContent(ofSecureField secureField: Widget, to content: String) {
        let secureField = secureField as! PasswordBox
        // Not an edit: the `PasswordChanging` and `PasswordChanged` this write raises are not
        // reported.
        internalState.textFieldReportedTexts[ObjectIdentifier(secureField)] = content
        secureField.password = content
    }

    public func getContent(ofSecureField secureField: Widget) -> String {
        (secureField as! PasswordBox).password
    }
}

// MARK: TextBoxProtocol

protocol TextBoxProtocol: Control {
    var inputScope: InputScope! { get set }
}

extension TextBox: TextBoxProtocol {}
extension PasswordBox: TextBoxProtocol {}
