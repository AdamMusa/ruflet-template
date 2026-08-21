#if os(iOS)
  import SwiftUI
  import UIKit

  struct RufletNativeTabBarItem: Equatable {
    let id: Int
    let title: String?
    let icon: RufletAppleIcon?
    let selectedIcon: RufletAppleIcon?
    let badge: String?
    let enabled: Bool
    let accessibilityHint: String?
  }

  /// Public UIKit `UITabBar` bridge. UIKit owns the bar's shape, blur/glass,
  /// layout, focus, pointer behavior, accessibility, and future iOS appearance.
  @MainActor
  struct RufletNativeTabBar: UIViewRepresentable {
    let items: [RufletNativeTabBarItem]
    let selectedIndex: Int
    let enabled: Bool
    let iconSize: CGFloat
    let backgroundColor: Color?
    let selectedColor: Color?
    let unselectedColor: Color?
    let onSelect: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIView(context: Context) -> UITabBar {
      let tabBar = UITabBar(frame: .zero)
      tabBar.delegate = context.coordinator
      tabBar.itemPositioning = .automatic
      return tabBar
    }

    func updateUIView(_ tabBar: UITabBar, context: Context) {
      context.coordinator.onSelect = onSelect

      if context.coordinator.items != items || context.coordinator.iconSize != iconSize {
        context.coordinator.items = items
        context.coordinator.iconSize = iconSize
        let nativeItems = items.enumerated().map { index, item in
          let normalImage = item.icon?.rufletUIImage(pointSize: iconSize)
          let selectedImage = (item.selectedIcon ?? item.icon)?.rufletUIImage(pointSize: iconSize)
          let native = UITabBarItem(
            title: item.title,
            image: normalImage,
            selectedImage: selectedImage)
          native.tag = index
          native.badgeValue = item.badge
          native.isEnabled = item.enabled && enabled
          native.accessibilityHint = item.accessibilityHint
          return native
        }
        tabBar.setItems(nativeItems, animated: false)
      } else {
        for (index, item) in items.enumerated() where tabBar.items?.indices.contains(index) == true
        {
          tabBar.items?[index].isEnabled = item.enabled && enabled
        }
      }

      if tabBar.items?.indices.contains(selectedIndex) == true {
        tabBar.selectedItem = tabBar.items?[selectedIndex]
      } else {
        tabBar.selectedItem = nil
      }
      tabBar.isUserInteractionEnabled = enabled
      tabBar.tintColor = selectedColor.map(UIColor.init)
      tabBar.unselectedItemTintColor = unselectedColor.map(UIColor.init)

      let appearance = UITabBarAppearance()
      if let backgroundColor {
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(backgroundColor)
      } else {
        appearance.configureWithDefaultBackground()
      }
      tabBar.standardAppearance = appearance
      tabBar.scrollEdgeAppearance = appearance
    }

    @MainActor
    final class Coordinator: NSObject, UITabBarDelegate {
      var onSelect: (Int) -> Void
      var items: [RufletNativeTabBarItem] = []
      var iconSize: CGFloat = 0

      init(onSelect: @escaping (Int) -> Void) { self.onSelect = onSelect }

      func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        onSelect(item.tag)
      }
    }
  }
#endif
