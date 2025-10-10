import SwiftUI
import UIKit

final class WrappingLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        preferredMaxLayoutWidth = bounds.width
    }
}

public struct InlineTitleLabel: UIViewRepresentable {
    let title: String
    let flairText: String?
    let isNSFW: Bool
    let isSpoiler: Bool
    let showDomain: Bool
    let domainText: String
    let flairBackground: UIColor
    let flairTextColor: UIColor
    let textColor: UIColor
    let titlePointSize: CGFloat
    let titleWeight: UIFont.Weight
    let pillPointSize: CGFloat
    let pillWeight: UIFont.Weight
    let isPinned: Bool
    let isLocked: Bool
    let isArchived: Bool
    let gildedCount: Int

    public init(title: String,
                flairText: String?,
                isNSFW: Bool,
                isSpoiler: Bool,
                showDomain: Bool,
                domainText: String,
                flairBackground: UIColor,
                flairTextColor: UIColor,
                textColor: UIColor,
                titlePointSize: CGFloat,
                titleWeight: UIFont.Weight,
                pillPointSize: CGFloat,
                pillWeight: UIFont.Weight,
                isPinned: Bool = false,
                isLocked: Bool = false,
                isArchived: Bool = false,
                gildedCount: Int = 0) {
        self.title = title
        self.flairText = flairText
        self.isNSFW = isNSFW
        self.isSpoiler = isSpoiler
        self.showDomain = showDomain
        self.domainText = domainText
        self.flairBackground = flairBackground
        self.flairTextColor = flairTextColor
        self.textColor = textColor
        self.titlePointSize = titlePointSize
        self.titleWeight = titleWeight
        self.pillPointSize = pillPointSize
        self.pillWeight = pillWeight
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.isArchived = isArchived
        self.gildedCount = gildedCount
    }

    public func makeUIView(context: Context) -> UILabel {
        let label = WrappingLabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    public func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = buildAttributedString()
        if let wrap = uiView as? WrappingLabel {
            wrap.preferredMaxLayoutWidth = wrap.bounds.width
        } else {
            uiView.preferredMaxLayoutWidth = uiView.bounds.width
        }
    }

    private func buildAttributedString() -> NSAttributedString {
        let baseFont = UIFont.systemFont(ofSize: titlePointSize, weight: titleWeight)
        let base: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor
        ]
        let out = NSMutableAttributedString(string: title, attributes: base)

        func appendSpace() { out.append(NSAttributedString(string: " ", attributes: base)) }

        if let flair = flairText, !flair.isEmpty {
            appendSpace()
            out.append(NSAttributedString(attachment: pillAttachment(text: flair, textColor: flairTextColor, backgroundColor: flairBackground)))
        }
        if isNSFW {
            appendSpace()
            out.append(NSAttributedString(attachment: pillAttachment(text: "NSFW", textColor: .white, backgroundColor: .red)))
        }
        if isSpoiler {
            appendSpace()
            out.append(NSAttributedString(attachment: pillAttachment(text: "SPOILER", textColor: .white, backgroundColor: .orange)))
        }
        if showDomain {
            appendSpace()
            out.append(NSAttributedString(attachment: pillAttachment(text: domainText, textColor: .secondaryLabel, backgroundColor: .secondarySystemFill)))
        }
        if isPinned {
            appendSpace()
            out.append(NSAttributedString(attachment: iconPillAttachment(systemName: "pin.fill", tintColor: .systemGreen)))
        }
        if gildedCount > 0 {
            appendSpace()
            let text = gildedCount > 1 ? "\(gildedCount)" : nil
            out.append(NSAttributedString(attachment: iconPillAttachment(systemName: "seal.fill", tintColor: .systemYellow, text: text)))
        }
        if isLocked {
            appendSpace()
            out.append(NSAttributedString(attachment: iconPillAttachment(systemName: "lock.fill", tintColor: .systemOrange)))
        }
        if isArchived {
            appendSpace()
            out.append(NSAttributedString(attachment: iconPillAttachment(systemName: "archivebox.fill", tintColor: .secondaryLabel)))
        }
        return out
    }

    private func pillAttachment(text: String, textColor: UIColor, backgroundColor: UIColor) -> NSTextAttachment {
        let pillFont = UIFont.systemFont(ofSize: pillPointSize, weight: pillWeight)
        let image = renderPill(text: text, font: pillFont, textColor: textColor, backgroundColor: backgroundColor)
        let attachment = NSTextAttachment()
        attachment.image = image
        let baselineFont = UIFont.systemFont(ofSize: titlePointSize, weight: titleWeight)
        let yOffset = (baselineFont.capHeight - image.size.height) / 2
        attachment.bounds = CGRect(x: 0, y: yOffset, width: image.size.width, height: image.size.height)
        return attachment
    }

    private func renderPill(text: String, font: UIFont, textColor: UIColor, backgroundColor: UIColor) -> UIImage {
        let paddingH: CGFloat = 6
        let paddingV: CGFloat = 2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let size = CGSize(width: ceil(textSize.width + paddingH * 2), height: ceil(textSize.height + paddingV * 2))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: size.height / 2)
            backgroundColor.setFill()
            path.fill()
            let textOrigin = CGPoint(x: paddingH, y: paddingV)
            (text as NSString).draw(at: textOrigin, withAttributes: attributes)
        }
    }

    private func iconPillAttachment(systemName: String, tintColor: UIColor, text: String? = nil) -> NSTextAttachment {
        let image = renderIconPill(systemName: systemName, tintColor: tintColor, text: text)
        let attachment = NSTextAttachment()
        attachment.image = image
        let baselineFont = UIFont.systemFont(ofSize: titlePointSize, weight: titleWeight)
        let yOffset = (baselineFont.capHeight - image.size.height) / 2
        attachment.bounds = CGRect(x: 0, y: yOffset, width: image.size.width, height: image.size.height)
        return attachment
    }

    private func renderIconPill(systemName: String, tintColor: UIColor, text: String?) -> UIImage {
        let paddingH: CGFloat = 5
        let paddingV: CGFloat = 2
        let iconSize = pillPointSize
        let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
        guard let icon = UIImage(systemName: systemName, withConfiguration: config)?.withTintColor(tintColor, renderingMode: .alwaysOriginal) else {
            return UIImage()
        }

        var totalWidth = icon.size.width + paddingH * 2
        var textSize: CGSize = .zero

        if let text = text {
            let font = UIFont.systemFont(ofSize: pillPointSize, weight: pillWeight)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            textSize = (text as NSString).size(withAttributes: attributes)
            totalWidth += textSize.width + 3 // 3pt spacing between icon and text
        }

        let height = max(icon.size.height, textSize.height) + paddingV * 2
        let size = CGSize(width: ceil(totalWidth), height: ceil(height))
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: size.height / 2)
            UIColor.secondarySystemFill.setFill()
            path.fill()

            let iconY = (size.height - icon.size.height) / 2
            icon.draw(at: CGPoint(x: paddingH, y: iconY))

            if let text = text {
                let font = UIFont.systemFont(ofSize: pillPointSize, weight: pillWeight)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let textX = paddingH + icon.size.width + 3
                let textY = (size.height - textSize.height) / 2
                (text as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
            }
        }
    }
}
