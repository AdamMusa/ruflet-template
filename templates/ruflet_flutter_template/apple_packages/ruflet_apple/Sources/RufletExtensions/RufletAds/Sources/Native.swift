import RufletEngine
import SwiftUI

#if os(iOS)
import GoogleMobileAds
import RufletProtocol
import UIKit

struct NativeAdControl: View {
  @ObservedObject var control: RufletControl

  var body: some View {
    if control.string("factory_id") == nil, control.value("template_style") == nil {
      Text("factory_id or template_style is required").foregroundStyle(.red)
    } else {
      RufletNativeAdRepresentable(control: control)
        .frame(minHeight: templateHeight)
    }
  }

  private var templateHeight: Double {
    rufletNativeTemplateStyle(control.value("template_style"))?.templateType == .small ? 100 : 300
  }
}

private struct RufletNativeAdRepresentable: UIViewRepresentable {
  let control: RufletControl

  func makeCoordinator() -> Coordinator { Coordinator(control: control) }

  func makeUIView(context: Context) -> RufletNativeAdContainer {
    let view = RufletNativeAdContainer()
    context.coordinator.attach(view)
    context.coordinator.update(control)
    return view
  }

  func updateUIView(_ view: RufletNativeAdContainer, context: Context) {
    context.coordinator.attach(view)
    context.coordinator.update(control)
  }

  static func dismantleUIView(_ view: RufletNativeAdContainer, coordinator: Coordinator) {
    coordinator.detach()
    view.nativeAd = nil
  }

  @MainActor
  final class Coordinator: NSObject, NativeAdLoaderDelegate, NativeAdDelegate {
    private var control: RufletControl
    private weak var view: RufletNativeAdContainer?
    private var loader: AdLoader?
    private var configuration: Configuration?

    init(control: RufletControl) { self.control = control }

    func attach(_ view: RufletNativeAdContainer) { self.view = view }

    func detach() {
      loader?.delegate = nil
      loader = nil
      view = nil
    }

    func update(_ control: RufletControl) {
      self.control = control
      let next = Configuration(control: control)
      guard next != configuration, let view else { return }
      configuration = next
      view.apply(next.templateStyle)
      let loader = AdLoader(
        adUnitID: next.unitID,
        rootViewController: nil,
        adTypes: [.native],
        options: nil)
      loader.delegate = self
      self.loader = loader
      loader.load(next.request.googleRequest())
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
      nativeAd.delegate = self
      nativeAd.paidEventHandler = { [weak self] value in
        Task { @MainActor in
          self?.control.triggerEvent("paid", data: rufletPaidEvent(
            value: value.value.doubleValue,
            precision: Self.precision(value.precision),
            currencyCode: value.currencyCode))
        }
      }
      view?.display(nativeAd)
      control.triggerEvent("load")
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
      control.triggerEvent("error", data: .string(String(describing: error)))
    }

    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
      control.triggerEvent("impression")
    }

    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
      control.triggerEvent("click")
    }

    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
      control.triggerEvent("open")
    }

    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
      control.triggerEvent("will_dismiss")
    }

    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
      control.triggerEvent("close")
    }

    private static func precision(_ value: AdValuePrecision) -> RufletAdPrecision {
      switch value {
      case .estimated: .estimated
      case .publisherProvided: .publisherProvided
      case .precise: .precise
      default: .unknown
      }
    }
  }

  private struct Configuration: Equatable {
    let unitID: String
    let request: RufletAdRequest
    let templateFingerprint: RufletValue?
    let templateStyle: RufletNativeTemplateStyle?

    @MainActor
    init(control: RufletControl) {
      unitID = control.string("unit_id") ?? "ca-app-pub-3940256099942544/3986624511"
      request = RufletAdRequest(control.value("request"))
      templateFingerprint = control.value("template_style")
      templateStyle = rufletNativeTemplateStyle(templateFingerprint)
    }

    static func == (lhs: Configuration, rhs: Configuration) -> Bool {
      lhs.unitID == rhs.unitID
        && lhs.request == rhs.request
        && lhs.templateFingerprint == rhs.templateFingerprint
    }
  }
}

@MainActor
private final class RufletNativeAdContainer: NativeAdView {
  private let media = MediaView()
  private let icon = UIImageView()
  private let headline = UILabel()
  private let bodyLabel = UILabel()
  private let advertiser = UILabel()
  private let callToAction = UIButton(type: .system)
  private let textStack = UIStackView()
  private let rootStack = UIStackView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    buildHierarchy()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    buildHierarchy()
  }

  func apply(_ style: RufletNativeTemplateStyle?) {
    backgroundColor = style?.mainBackgroundColor.map(UIColor.init) ?? .secondarySystemBackground
    layer.cornerRadius = style?.cornerRadius ?? 8
    clipsToBounds = true
    style?.primary?.apply(to: headline)
    style?.secondary?.apply(to: bodyLabel)
    style?.tertiary?.apply(to: advertiser)
    style?.callToAction?.apply(to: callToAction)
    media.isHidden = style?.templateType == .small
  }

  func display(_ ad: NativeAd) {
    headline.text = ad.headline
    bodyLabel.text = ad.body
    advertiser.text = ad.advertiser
    icon.image = ad.icon?.image
    icon.isHidden = ad.icon == nil
    media.mediaContent = ad.mediaContent
    callToAction.setTitle(ad.callToAction, for: .normal)
    callToAction.isHidden = ad.callToAction == nil
    callToAction.isUserInteractionEnabled = false
    nativeAd = ad
  }

  private func buildHierarchy() {
    guard rootStack.superview == nil else { return }
    headline.numberOfLines = 2
    headline.font = .preferredFont(forTextStyle: .headline)
    bodyLabel.numberOfLines = 3
    bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
    advertiser.font = .preferredFont(forTextStyle: .caption1)
    advertiser.textColor = .secondaryLabel
    icon.contentMode = .scaleAspectFit
    icon.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 48),
      icon.heightAnchor.constraint(equalToConstant: 48),
    ])

    textStack.axis = .vertical
    textStack.spacing = 4
    textStack.addArrangedSubview(headline)
    textStack.addArrangedSubview(bodyLabel)
    textStack.addArrangedSubview(advertiser)
    textStack.addArrangedSubview(callToAction)

    let summary = UIStackView(arrangedSubviews: [icon, textStack])
    summary.axis = .horizontal
    summary.alignment = .top
    summary.spacing = 8
    rootStack.axis = .vertical
    rootStack.spacing = 8
    rootStack.addArrangedSubview(media)
    rootStack.addArrangedSubview(summary)
    rootStack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(rootStack)
    NSLayoutConstraint.activate([
      rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
      rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
      media.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
    ])

    headlineView = headline
    bodyView = bodyLabel
    advertiserView = advertiser
    iconView = icon
    mediaView = media
    callToActionView = callToAction
  }
}
#endif
