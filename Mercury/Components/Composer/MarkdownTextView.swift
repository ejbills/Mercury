import SwiftUI
import UIKit

struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var isFirstResponder: Bool

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.isEditable = true
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.text = text
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
        }

        // Manage first responder
        if isFirstResponder, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFirstResponder, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView
        init(_ parent: MarkdownTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            if parent.text != newText {
                DispatchQueue.main.async {
                    self.parent.text = newText
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let newRange = textView.selectedRange
            if parent.selectedRange != newRange {
                DispatchQueue.main.async {
                    self.parent.selectedRange = newRange
                }
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if parent.isFirstResponder == false {
                DispatchQueue.main.async {
                    self.parent.isFirstResponder = true
                }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFirstResponder == true {
                DispatchQueue.main.async {
                    self.parent.isFirstResponder = false
                }
            }
        }
    }
}
