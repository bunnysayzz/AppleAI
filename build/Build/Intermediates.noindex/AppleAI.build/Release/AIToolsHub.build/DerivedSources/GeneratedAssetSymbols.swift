import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
extension ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
extension ImageResource {

    /// The "MenuBarIcon" asset catalog image resource.
    static let menuBarIcon = ImageResource(name: "MenuBarIcon", bundle: resourceBundle)

    /// The "AILogos" asset catalog resource namespace.
    enum AILogos {

        /// The "AILogos/chatgpt" asset catalog image resource.
        static let chatgpt = ImageResource(name: "AILogos/chatgpt", bundle: resourceBundle)

        /// The "AILogos/claude" asset catalog image resource.
        static let claude = ImageResource(name: "AILogos/claude", bundle: resourceBundle)

        /// The "AILogos/copilot" asset catalog image resource.
        static let copilot = ImageResource(name: "AILogos/copilot", bundle: resourceBundle)

        /// The "AILogos/deekseek" asset catalog image resource.
        static let deekseek = ImageResource(name: "AILogos/deekseek", bundle: resourceBundle)

        /// The "AILogos/grok" asset catalog image resource.
        static let grok = ImageResource(name: "AILogos/grok", bundle: resourceBundle)

        /// The "AILogos/perplexity" asset catalog image resource.
        static let perplexity = ImageResource(name: "AILogos/perplexity", bundle: resourceBundle)

    }

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "MenuBarIcon" asset catalog image.
    static var menuBarIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .menuBarIcon)
#else
        .init()
#endif
    }

    /// The "AILogos" asset catalog resource namespace.
    enum AILogos {

        /// The "AILogos/chatgpt" asset catalog image.
        static var chatgpt: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .AILogos.chatgpt)
#else
            .init()
#endif
        }

        /// The "AILogos/claude" asset catalog image.
        static var claude: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .AILogos.claude)
#else
            .init()
#endif
        }

        /// The "AILogos/copilot" asset catalog image.
        static var copilot: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .AILogos.copilot)
#else
            .init()
#endif
        }

        /// The "AILogos/deekseek" asset catalog image.
        static var deekseek: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .AILogos.deekseek)
#else
            .init()
#endif
        }

        /// The "AILogos/grok" asset catalog image.
        static var grok: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .AILogos.grok)
#else
            .init()
#endif
        }

        /// The "AILogos/perplexity" asset catalog image.
        static var perplexity: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .AILogos.perplexity)
#else
            .init()
#endif
        }

    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "MenuBarIcon" asset catalog image.
    static var menuBarIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .menuBarIcon)
#else
        .init()
#endif
    }

    /// The "AILogos" asset catalog resource namespace.
    enum AILogos {

        /// The "AILogos/chatgpt" asset catalog image.
        static var chatgpt: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .AILogos.chatgpt)
#else
            .init()
#endif
        }

        /// The "AILogos/claude" asset catalog image.
        static var claude: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .AILogos.claude)
#else
            .init()
#endif
        }

        /// The "AILogos/copilot" asset catalog image.
        static var copilot: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .AILogos.copilot)
#else
            .init()
#endif
        }

        /// The "AILogos/deekseek" asset catalog image.
        static var deekseek: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .AILogos.deekseek)
#else
            .init()
#endif
        }

        /// The "AILogos/grok" asset catalog image.
        static var grok: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .AILogos.grok)
#else
            .init()
#endif
        }

        /// The "AILogos/perplexity" asset catalog image.
        static var perplexity: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .AILogos.perplexity)
#else
            .init()
#endif
        }

    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
@available(watchOS, unavailable)
extension ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
@available(watchOS, unavailable)
extension ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

// MARK: - Backwards Deployment Support -

/// A color resource.
struct ColorResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog color resource name.
    fileprivate let name: Swift.String

    /// An asset catalog color resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize a `ColorResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

/// An image resource.
struct ImageResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog image resource name.
    fileprivate let name: Swift.String

    /// An asset catalog image resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize an `ImageResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// Initialize a `NSColor` with a color resource.
    convenience init(resource: ColorResource) {
        self.init(named: NSColor.Name(resource.name), bundle: resource.bundle)!
    }

}

protocol _ACResourceInitProtocol {}
extension AppKit.NSImage: _ACResourceInitProtocol {}

@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension _ACResourceInitProtocol {

    /// Initialize a `NSImage` with an image resource.
    init(resource: ImageResource) {
        self = resource.bundle.image(forResource: NSImage.Name(resource.name))! as! Self
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// Initialize a `UIColor` with a color resource.
    convenience init(resource: ColorResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}

@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// Initialize a `UIImage` with an image resource.
    convenience init(resource: ImageResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    /// Initialize a `Color` with a color resource.
    init(_ resource: ColorResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Image {

    /// Initialize an `Image` with an image resource.
    init(_ resource: ImageResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}
#endif