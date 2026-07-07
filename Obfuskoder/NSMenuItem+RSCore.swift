//
//  NSMenuItem+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 1/5/26.
//  https://gist.github.com/brentsimmons/8dbe00e8acbeede26baaaebd06a867fc
//
//  Swift port of NetNewsWire's selective variant (NSMenuItem+RSCore.m):
//  https://github.com/Ranchero-Software/NetNewsWire/blob/main/Modules/RSCore/Sources/RSCoreObjC/NSMenuItem%2BRSCore.m
//

#if os(macOS)
import AppKit
import ObjectiveC

private nonisolated(unsafe) var shouldShowImageKey: UInt8 = 0

extension NSMenuItem {

    /// Opt-in: when true, this item keeps its icon even after `disableIcons()`.
    public var shouldShowImage: Bool {
        get { (objc_getAssociatedObject(self, &shouldShowImageKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &shouldShowImageKey, newValue,
                                       .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Opt-in by title (app addition, not in RSCore): top-level items whose
    /// titles appear here keep their icons. Unlike the per-instance flag,
    /// this survives SwiftUI recreating its Commands-generated NSMenuItems.
    public static var iconAllowlist: Set<String> = []

    /// Hides icons for top-level main-menu items only. Icons remain for:
    /// items flagged `shouldShowImage`, toolbar-button representations,
    /// anything deeper than the menu bar's first level (submenus like
    /// Services or Move & Resize, context menus, popup buttons), and
    /// untitled items.
    ///
    /// Call early — `AppDelegate.init` is good.
    ///
    /// Idempotent: `method_exchangeImplementations` is an involution, so a
    /// second call would silently restore every icon. The guard makes repeat
    /// calls no-ops.
    public static func disableIcons() {
        guard !didSwizzleIcons else { return }
        let originalSelector = #selector(getter: image)
        let swizzledSelector = #selector(swizzledImage)

        guard let originalMethod = class_getInstanceMethod(NSMenuItem.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(NSMenuItem.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
        didSwizzleIcons = true
    }

    private static var didSwizzleIcons = false

    @objc private func swizzledImage() -> NSImage? {
        if shouldShowImage || Self.iconAllowlist.contains(title)
            || isToolbarItemRepresentation || !isMainMenuItem || title.isEmpty {
            // Implementations are exchanged: this calls the original getter.
            return swizzledImage()
        }
        return nil
    }

    /// Menu items not attached to any menu are likely toolbar button representations.
    private var isToolbarItemRepresentation: Bool {
        menu == nil
    }

    /// True when the parent menu hangs directly off the menu bar. Anything
    /// deeper (Services, Move & Resize, Full Screen Tile, context menus)
    /// keeps its icons.
    private var isMainMenuItem: Bool {
        menu?.supermenu == NSApplication.shared.mainMenu
    }
}

#endif
