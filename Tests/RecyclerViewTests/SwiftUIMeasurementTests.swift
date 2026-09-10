import SwiftUI
import XCTest
@testable import RecyclerView

@MainActor
final class SwiftUIMeasurementTests: XCTestCase {
    private let longText = String(repeating: "wrap ", count: 60)

    func testFixedHeightIsMeasuredExactly() {
        let height = SwiftUIMeasurement.fittingHeight(of: Color.red.frame(height: 90), width: 320)
        XCTAssertEqual(height, 90, accuracy: 0.5)
    }

    func testWrappingTextGrowsTallerWhenNarrower() {
        let narrow = SwiftUIMeasurement.fittingHeight(of: Text(longText), width: 80)
        let wide = SwiftUIMeasurement.fittingHeight(of: Text(longText), width: 2000)
        XCTAssertGreaterThan(narrow, wide * 3)
    }

    func testVerticalSpacerDoesNotStretchTheRow() {
        let text = SwiftUIMeasurement.fittingHeight(of: Text("Title"), width: 320)
        let withSpacer = SwiftUIMeasurement.fittingHeight(of: VStack(spacing: 0) { Text("Title"); Spacer(minLength: 0) }, width: 320)
        XCTAssertEqual(withSpacer, text, accuracy: 0.5)
    }

    func testMatchesTheHeightOfASelfSizingCell() {
        let row = VStack(alignment: .leading, spacing: 4) {
            Text("Headline").font(.headline)
            Text(longText).font(.subheadline)
        }
        .padding(12)

        let cell = ViewHolder<AnyView>(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        cell.bind(AnyView(row), itemID: "row", parentViewController: nil)
        let cellHeight = cell.systemLayoutSizeFitting(
            CGSize(width: 320, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        XCTAssertEqual(SwiftUIMeasurement.fittingHeight(of: row, width: 320), cellHeight, accuracy: 0.5)
        XCTAssertGreaterThan(cellHeight, 100)
    }
}
