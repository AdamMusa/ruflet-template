import SwiftUI

/// Apple-native port of Flet's `HeroControl`.
@MainActor
public struct HeroControl: View {
  @ObservedObject public var control: RufletControl
  @Environment(\.rufletHeroNamespace) private var namespace
  @EnvironmentObject private var transitionState: RufletHeroTransitionState

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    if control.child("content") == nil {
      ErrorControl("Hero.content must be provided and visible")
    } else if control.value("tag") == nil {
      ErrorControl("Hero.tag must be provided")
    } else {
      hero
    }
  }

  private var hero: AnyView {
    guard let namespace else {
      return AnyView(ErrorControl("Hero requires the root Ruflet hero scope"))
    }
    guard let content = control.buildWidget("content"), let tag = control.value("tag") else {
      return AnyView(ErrorControl("Hero.content must be provided and visible"))
    }
    return AnyView(
      LayoutControl(control: control) {
        if participatesInCurrentTransition {
          content.matchedGeometryEffect(
            id: rufletStableValueDescription(tag),
            in: namespace,
            properties: .frame,
            anchor: .center
          )
        } else {
          content
        }
      })
  }

  var transitionOnUserGestures: Bool {
    control.boolean("transition_on_user_gestures", default: false)
  }

  private var participatesInCurrentTransition: Bool {
    rufletHeroParticipatesInTransition(
      transitionOnUserGestures: transitionOnUserGestures,
      isInteractiveNavigation: transitionState.isInteractiveNavigation)
  }
}
