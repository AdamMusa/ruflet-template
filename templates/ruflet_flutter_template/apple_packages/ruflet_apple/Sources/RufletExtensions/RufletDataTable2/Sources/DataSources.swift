import Foundation

@MainActor
public final class RufletRestorableDessertSelections: ObservableObject {
  @Published public private(set) var selectedIndices: Set<Int>

  public init(selectedIndices: Set<Int> = []) {
    self.selectedIndices = selectedIndices
  }

  public func isSelected(_ index: Int) -> Bool { selectedIndices.contains(index) }

  public func setSelections(from desserts: [RufletDessert]) {
    selectedIndices = Set(desserts.indices.filter { desserts[$0].selected })
  }

  public func restore(_ primitive: [Int]) { selectedIndices = Set(primitive) }
  public var primitive: [Int] { selectedIndices.sorted() }
}

public struct RufletDessert: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let name: String
  public let calories: Int
  public let fat: Double
  public let carbs: Int
  public let protein: Double
  public let sodium: Int
  public let calcium: Int
  public let iron: Int
  public var selected: Bool

  public init(
    id: UUID = UUID(),
    name: String,
    calories: Int,
    fat: Double,
    carbs: Int,
    protein: Double,
    sodium: Int,
    calcium: Int,
    iron: Int,
    selected: Bool = false
  ) {
    self.id = id
    self.name = name
    self.calories = calories
    self.fat = fat
    self.carbs = carbs
    self.protein = protein
    self.sodium = sodium
    self.calcium = calcium
    self.iron = iron
    self.selected = selected
  }
}

private let rufletDessertSampleData: [RufletDessert] = {
  let base = [
    RufletDessert(name: "Frozen Yogurt", calories: 159, fat: 6, carbs: 24, protein: 4, sodium: 87, calcium: 14, iron: 1),
    RufletDessert(name: "Ice Cream Sandwich", calories: 237, fat: 9, carbs: 37, protein: 4.3, sodium: 129, calcium: 8, iron: 1),
    RufletDessert(name: "Eclair", calories: 262, fat: 16, carbs: 24, protein: 6, sodium: 337, calcium: 6, iron: 7),
    RufletDessert(name: "Cupcake", calories: 305, fat: 3.7, carbs: 67, protein: 4.3, sodium: 413, calcium: 3, iron: 8),
    RufletDessert(name: "Gingerbread", calories: 356, fat: 16, carbs: 49, protein: 3.9, sodium: 327, calcium: 7, iron: 16),
    RufletDessert(name: "Jelly Bean", calories: 375, fat: 0, carbs: 94, protein: 0, sodium: 50, calcium: 0, iron: 0),
    RufletDessert(name: "Lollipop", calories: 392, fat: 0.2, carbs: 98, protein: 0, sodium: 38, calcium: 0, iron: 2),
    RufletDessert(name: "Honeycomb", calories: 408, fat: 3.2, carbs: 87, protein: 6.5, sodium: 562, calcium: 0, iron: 45),
    RufletDessert(name: "Donut", calories: 452, fat: 25, carbs: 51, protein: 4.9, sodium: 326, calcium: 2, iron: 22),
    RufletDessert(name: "Apple Pie", calories: 518, fat: 26, carbs: 65, protein: 7, sodium: 54, calcium: 12, iron: 6),
  ]
  let sugared = base.map {
    RufletDessert(name: $0.name + " with sugar", calories: $0.calories + 9, fat: $0.fat, carbs: $0.carbs + 2, protein: $0.protein, sodium: $0.sodium, calcium: $0.calcium, iron: $0.iron)
  }
  let honeyed = base.map {
    RufletDessert(name: $0.name + " with honey", calories: $0.calories + 64, fat: $0.fat, carbs: $0.carbs + 12, protein: $0.protein, sodium: $0.sodium, calcium: $0.calcium, iron: $0.iron)
  }
  return base + sugared + honeyed
}()

@MainActor
public final class RufletDessertDataSource: ObservableObject {
  @Published public private(set) var desserts: [RufletDessert]
  public var hasRowTaps = false
  public var hasRowHeightOverrides = false
  public var hasZebraStripes = false

  public init(desserts: [RufletDessert]? = nil) {
    self.desserts = desserts ?? rufletDessertSampleData
  }

  public var selectedRowCount: Int { desserts.lazy.filter(\.selected).count }

  public func sort<Value: Comparable>(by field: KeyPath<RufletDessert, Value>, ascending: Bool) {
    desserts.sort {
      ascending ? $0[keyPath: field] < $1[keyPath: field] : $0[keyPath: field] > $1[keyPath: field]
    }
  }

  public func selectAll(_ selected: Bool) {
    for index in desserts.indices { desserts[index].selected = selected }
  }

  public func updateSelections(_ selections: RufletRestorableDessertSelections) {
    for index in desserts.indices { desserts[index].selected = selections.isSelected(index) }
  }

  public static let sample = rufletDessertSampleData
}

public struct RufletDessertPage: Sendable {
  public let totalRecords: Int
  public let data: [RufletDessert]
}

public actor RufletDessertsDataSourceAsync {
  private let source: [RufletDessert]
  private var sortColumn = "name"
  private var sortAscending = true
  private var calorieRange: ClosedRange<Int>?

  public init(source: [RufletDessert]? = nil) {
    self.source = source ?? rufletDessertSampleData.flatMap { item in
      [item,
       RufletDessert(name: item.name + " x2", calories: item.calories, fat: item.fat, carbs: item.carbs, protein: item.protein, sodium: item.sodium, calcium: item.calcium, iron: item.iron),
       RufletDessert(name: item.name + " x3", calories: item.calories, fat: item.fat, carbs: item.carbs, protein: item.protein, sodium: item.sodium, calcium: item.calcium, iron: item.iron)]
    }
  }

  public func configureSort(column: String, ascending: Bool) {
    sortColumn = column
    sortAscending = ascending
  }

  public func filterCalories(_ range: ClosedRange<Int>?) { calorieRange = range }

  public func rows(startIndex: Int, count: Int) async -> RufletDessertPage {
    var filtered = source.filter { calorieRange?.contains($0.calories) ?? true }
    filtered.sort { compare($0, $1) }
    let start = min(max(startIndex, 0), filtered.count)
    let end = min(start + max(count, 0), filtered.count)
    return RufletDessertPage(totalRecords: filtered.count, data: Array(filtered[start ..< end]))
  }

  private func compare(_ lhs: RufletDessert, _ rhs: RufletDessert) -> Bool {
    let result: Bool
    switch sortColumn {
    case "calories": result = lhs.calories < rhs.calories
    case "fat": result = lhs.fat < rhs.fat
    case "carbs": result = lhs.carbs < rhs.carbs
    case "protein": result = lhs.protein < rhs.protein
    case "sodium": result = lhs.sodium < rhs.sodium
    case "calcium": result = lhs.calcium < rhs.calcium
    case "iron": result = lhs.iron < rhs.iron
    default: result = lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
    return sortAscending ? result : !result
  }
}
