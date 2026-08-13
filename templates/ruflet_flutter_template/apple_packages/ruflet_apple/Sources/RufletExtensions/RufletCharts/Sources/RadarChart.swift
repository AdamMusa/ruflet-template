import RufletEngine
import RufletProtocol
import SwiftUI

struct RadarChartControl: View {
  @ObservedObject var control: RufletControl

  private var dataSets: [RadarDataSet] {
    control.children("data_sets").enumerated().map {
      RadarDataSet.parse($0.element, index: $0.offset)
    }
  }

  private var titleControls: [RufletControl] {
    control.children("titles", visibleOnly: false)
  }

  var body: some View {
    ChartFrame(control: control) {
      GeometryReader { proxy in
        let configuration = RadarChartConfiguration(control: control)
        let layout = RadarChartLayout(
          size: proxy.size,
          dataSets: dataSets,
          configuration: configuration)
        Canvas { context, _ in
          draw(context: &context, layout: layout, configuration: configuration)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0).onEnded { value in
            emitTap(
              at: value.location,
              layout: layout,
              configuration: configuration)
          })
      }
    }
  }

  private func draw(
    context: inout GraphicsContext,
    layout: RadarChartLayout,
    configuration: RadarChartConfiguration
  ) {
    guard layout.count >= 3 else { return }
    let outerPath = radarPath(layout: layout, radius: layout.radius, shape: configuration.shape)
    context.fill(outerPath, with: .color(configuration.radarBackgroundColor))
    for index in 0..<layout.count {
      var spoke = Path()
      spoke.move(to: layout.center)
      spoke.addLine(to: layout.vertex(index: index, radius: layout.radius))
      context.stroke(
        spoke,
        with: .color(configuration.gridBorder.color),
        lineWidth: configuration.gridBorder.width)
    }
    drawTicks(context: &context, layout: layout, configuration: configuration)
    context.stroke(
      outerPath,
      with: .color(configuration.radarBorder.color),
      lineWidth: configuration.radarBorder.width)
    for dataSet in dataSets {
      var path = Path()
      for (index, value) in dataSet.entries.enumerated() {
        let point = layout.vertex(index: index, radius: layout.scaledRadius(for: value))
        index == 0 ? path.move(to: point) : path.addLine(to: point)
      }
      path.closeSubpath()
      let shading =
        dataSet.fillGradient?.shading(
          from: CGPoint(x: layout.center.x - layout.radius, y: layout.center.y),
          to: CGPoint(x: layout.center.x + layout.radius, y: layout.center.y))
        ?? .color(dataSet.fillColor)
      context.fill(path, with: shading)
      context.stroke(
        path, with: .color(dataSet.borderColor), lineWidth: CGFloat(dataSet.borderWidth))
      for (index, value) in dataSet.entries.enumerated() {
        let point = layout.vertex(index: index, radius: layout.scaledRadius(for: value))
        let entryRadius = CGFloat(max(0, dataSet.entryRadius))
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: point.x - entryRadius,
              y: point.y - entryRadius,
              width: entryRadius * 2,
              height: entryRadius * 2)),
          with: .color(dataSet.borderColor))
      }
    }
    drawTitles(context: &context, layout: layout, configuration: configuration)
    drawChartBorder(context: &context, size: layout.size, border: configuration.chartBorder)
  }

  private func drawTicks(
    context: inout GraphicsContext,
    layout: RadarChartLayout,
    configuration: RadarChartConfiguration
  ) {
    for tick in layout.ticks {
      let path = radarPath(layout: layout, radius: tick.radius, shape: configuration.shape)
      context.stroke(
        path,
        with: .color(configuration.tickBorder.color),
        lineWidth: configuration.tickBorder.width)
      let text = styledTitle(String(format: "%.1f", tick.value), style: configuration.tickStyle)
      context.draw(
        text,
        at: CGPoint(x: layout.center.x + 5, y: layout.center.y - tick.radius),
        anchor: .bottomLeading)
    }
  }

  private func drawTitles(
    context: inout GraphicsContext,
    layout: RadarChartLayout,
    configuration: RadarChartConfiguration
  ) {
    for (index, titleControl) in titleControls.prefix(layout.count).enumerated() {
      let title = RadarChartTitleConfiguration.parse(
        titleControl,
        defaultAngle: Double(index) / Double(layout.count) * 360,
        defaultPositionPercentageOffset: configuration.titlePositionPercentageOffset)
      guard !title.text.isEmpty else { continue }
      let text = styledTitle(title.text, style: configuration.titleStyle)
      let resolved = context.resolve(text)
      let measured = resolved.measure(
        in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
      let position = title.position(
        index: index,
        count: layout.count,
        radius: layout.radius,
        center: layout.center,
        textHeight: measured.height)
      var transformed = context
      transformed.translateBy(x: position.x, y: position.y)
      transformed.rotate(by: .degrees(title.angle))
      transformed.translateBy(x: -position.x, y: -position.y)
      transformed.draw(resolved, at: position, anchor: .center)
    }
  }

  private func styledTitle(_ value: String, style: RufletTextStyle?) -> Text {
    var result = Text(value)
    if let family = style?.fontFamily, let size = style?.size {
      result = result.font(.custom(family, size: size))
    } else if let size = style?.size {
      result = result.font(.system(size: size))
    }
    if let weight = style?.weight { result = result.fontWeight(weight) }
    if style?.italic == true { result = result.italic() }
    if let color = style?.color { result = result.foregroundColor(color) }
    if let spacing = style?.letterSpacing { result = result.kerning(spacing) }
    if let style {
      result = result.underline(style.decoration & 0x1 > 0, color: style.decorationColor)
      result = result.strikethrough(style.decoration & 0x4 > 0, color: style.decorationColor)
    }
    return result
  }

  private func emitTap(
    at location: CGPoint,
    layout: RadarChartLayout,
    configuration: RadarChartConfiguration
  ) {
    guard configuration.interactive, control.hasEventHandler("event") else {
      return
    }
    let hit = layout.hitTest(
      location,
      dataSets: dataSets,
      threshold: configuration.touchSpotThreshold)
    control.triggerEvent(
      "event",
      data: .map([
        "type": .string("tapUp"),
        "data_set_index": hit.map { .int(Int64($0.dataSetIndex)) } ?? .null,
        "entry_index": hit.map { .int(Int64($0.entryIndex)) } ?? .null,
        "entry_value": hit.map { .double($0.entryValue) } ?? .null,
      ]))
  }

  private func radarPath(
    layout: RadarChartLayout,
    radius: CGFloat,
    shape: RadarShape
  ) -> Path {
    if shape == .circle {
      return Path(
        ellipseIn: CGRect(
          x: layout.center.x - radius,
          y: layout.center.y - radius,
          width: radius * 2,
          height: radius * 2))
    }
    var path = Path()
    for index in 0..<layout.count {
      let point = layout.vertex(index: index, radius: radius)
      index == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
  }

  private func drawChartBorder(
    context: inout GraphicsContext,
    size: CGSize,
    border: RufletBorder?
  ) {
    guard let border else { return }
    let bounds = CGRect(origin: .zero, size: size)
    drawBorderSide(
      border.left,
      from: CGPoint(x: bounds.minX, y: bounds.minY),
      to: CGPoint(x: bounds.minX, y: bounds.maxY),
      context: &context)
    drawBorderSide(
      border.top,
      from: CGPoint(x: bounds.minX, y: bounds.minY),
      to: CGPoint(x: bounds.maxX, y: bounds.minY),
      context: &context)
    drawBorderSide(
      border.right,
      from: CGPoint(x: bounds.maxX, y: bounds.minY),
      to: CGPoint(x: bounds.maxX, y: bounds.maxY),
      context: &context)
    drawBorderSide(
      border.bottom,
      from: CGPoint(x: bounds.minX, y: bounds.maxY),
      to: CGPoint(x: bounds.maxX, y: bounds.maxY),
      context: &context)
  }

  private func drawBorderSide(
    _ side: RufletBorderSide?,
    from start: CGPoint,
    to end: CGPoint,
    context: inout GraphicsContext
  ) {
    guard let side, side.width > 0 else { return }
    var path = Path()
    path.move(to: start)
    path.addLine(to: end)
    context.stroke(path, with: .color(side.color), lineWidth: CGFloat(side.width))
  }
}
