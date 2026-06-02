import UIKit
import SwiftUI

public enum RecyclerViewLayoutManager: Equatable {
    case linear(orientation: Axis = .vertical, spacing: CGFloat = 0)
    case grid(spanCount: Int, spacing: CGFloat = 10, orientation: Axis = .vertical)
}

public enum RecyclerViewVerticalLayout: Equatable {
    case matchParent
    case wrapContent
}

public class ViewHolder<Content: View>: UICollectionViewCell {
    public static var reuseIdentifier: String {
        return String(describing: self)
    }
    
    private var hostingController: UIHostingController<Content>?
    private var itemID: String = "unknown"
    
    public func bind(_ view: Content, itemID: String, parentViewController: UIViewController?) {
        self.itemID = itemID
        
        if #available(iOS 16.0, *) {
            self.contentConfiguration = UIHostingConfiguration {
                view
            }
            .margins(.all, 0)
            .background(Color.clear)
        } else {
            if let hc = hostingController {
                hc.rootView = view
                hc.view.invalidateIntrinsicContentSize()
                hc.view.setNeedsLayout()
                hc.view.setNeedsUpdateConstraints()
                hc.view.layoutIfNeeded()
            } else {
                let hc = UIHostingController(rootView: view, ignoreSafeArea: true)
                hostingController = hc
                hc.view.backgroundColor = .clear
                hc.view.setNeedsUpdateConstraints()

                let cellView = hc.view!
                cellView.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(cellView)
                                
                NSLayoutConstraint.activate([
                    cellView.topAnchor.constraint(equalTo: contentView.topAnchor),
                    cellView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                    cellView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                    cellView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
                ])
                
                if let parent = parentViewController {
                    parent.addChild(hc)
                    hc.didMove(toParent: parent)
                }
            }
        }
    }
    
    override public func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        if #available(iOS 16.0, *) {
            return super.preferredLayoutAttributesFitting(layoutAttributes)
        }
        
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        guard let hc = hostingController else { return attributes }
        
        hc.view.setNeedsLayout()
        hc.view.layoutIfNeeded()
        contentView.setNeedsLayout()
        contentView.layoutIfNeeded()
        
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)
        let size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        attributes.frame.size.height = ceil(size.height)
        return attributes
    }
    
    private var isReversed: Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let collectionView = responder as? UICollectionView {
                return collectionView.transform != .identity
            }
            responder = responder?.next
        }
        return false
    }
    
    override public func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if isReversed {
            self.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            self.transform = .identity
        }
        CATransaction.commit()
    }
    
    override public func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if event == "transform" {
            return NSNull()
        }
        return super.action(for: layer, forKey: event)
    }
    
    deinit {
        if let hc = hostingController {
            hc.willMove(toParent: nil)
            hc.view.removeFromSuperview()
            hc.removeFromParent()
        }
    }
}

public class UIRecyclerView: UICollectionView {
    override public func action(for layer: CALayer, forKey event: String) -> CAAction? {
        if event == "transform" {
            return NSNull()
        }
        return super.action(for: layer, forKey: event)
    }
}

public class RecyclerViewAdapter<Item: Identifiable, Content: View>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    public var reverseLayout: Bool = false
    public var content: (Item) -> Content
    public var onItemClick: ((Int, Item) -> Void)?
    public var onLoadMore: ((Int, Int) -> Void)?
    public var layout: RecyclerViewLayoutManager = .linear(orientation: .vertical, spacing: 0)
    public var pageSize: Int = 50
    public var onScroll: ((CGPoint) -> Void)?
    
    private var currentPage: Int = 0
    private var previousTotalItemCount: Int = 0
    private var loadMoreTriggered: Bool = false
    
    public var items: [Item] = [] {
        didSet {
            let totalItemCount = items.count
            if totalItemCount < previousTotalItemCount {
                currentPage = 0
                previousTotalItemCount = totalItemCount
            }
            
            if totalItemCount > previousTotalItemCount {
                previousTotalItemCount = totalItemCount
                loadMoreTriggered = false
            }
        }
    }
    
    public weak var collectionView: UICollectionView?
    public weak var parentViewController: UIViewController?
    
    public init(collectionView: UICollectionView, content: @escaping (Item) -> Content) {
        self.collectionView = collectionView
        self.content = content
        super.init()
        
        collectionView.register(ViewHolder<Content>.self, forCellWithReuseIdentifier: ViewHolder<Content>.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    public func getItemIDString(for item: Item, at index: Int) -> String {
        let idString = String(describing: item.id)
        if idString == "nil" || idString.isEmpty || idString == "Optional(nil)" {
            return "placeholder_\(index)"
        }
        return idString
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ViewHolder<Content>.reuseIdentifier, for: indexPath) as? ViewHolder<Content> else {
            return UICollectionViewCell()
        }
        
        let item = items[indexPath.item]
        let view = content(item)
        
        if parentViewController == nil {
            parentViewController = collectionView.parentViewController
        }
        
        let itemIDString = getItemIDString(for: item, at: indexPath.item)
        cell.bind(view, itemID: itemIDString, parentViewController: parentViewController)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if reverseLayout {
            cell.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            cell.transform = .identity
        }
        CATransaction.commit()
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = items[indexPath.item]
        onItemClick?(indexPath.item, item)
    }
    
    public func notifyItemInserted(at index: Int) {
        guard let collectionView = collectionView else { return }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.insertItems(at: [indexPath])
    }
    
    public func notifyItemRemoved(at index: Int) {
        guard let collectionView = collectionView else { return }
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.deleteItems(at: [indexPath])
    }
    
    public func notifyItemChanged(at index: Int) {
        guard let collectionView = collectionView else { return }
        let indexPath = IndexPath(item: index, section: 0)
        if let cell = collectionView.cellForItem(at: indexPath) as? ViewHolder<Content> {
            let item = items[index]
            let view = content(item)
            let itemIDString = getItemIDString(for: item, at: index)
            cell.bind(view, itemID: itemIDString, parentViewController: parentViewController)
        } else {
            collectionView.reloadItems(at: [indexPath])
        }
    }
    
    public func notifyDataSetChanged() {
        collectionView?.reloadData()
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let totalItemCount = items.count
        guard totalItemCount > 0 else { return }
        
        let triggerThreshold = 5
        let resetThreshold = 10
        
        if indexPath.item < totalItemCount - resetThreshold {
            loadMoreTriggered = false
        }
        
        if !loadMoreTriggered && indexPath.item >= totalItemCount - triggerThreshold {
            guard pageSize > 0 else { return }
            
            let remainder = totalItemCount % pageSize
            if remainder > 0 {
                return
            }
            
            loadMoreTriggered = true
            let page = totalItemCount / pageSize
            onLoadMore?(page, totalItemCount)
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onScroll?(scrollView.contentOffset)
    }
    
    public func resetState() {
        currentPage = 0
        previousTotalItemCount = 0
        loadMoreTriggered = false
    }
}

public struct RecyclerView<Item: Identifiable, Content: View>: View {
    public static var statusBarHeight: CGFloat {
        return CGFloat(UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0)
    }
    public static var navBarHeight: CGFloat {
        return CGFloat(UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)
    }
    public static var displaySize: CGRect {
        return UIScreen.main.bounds
    }

    private let data: [Item]
    private let layout: RecyclerViewLayoutManager
    private let content: (Item) -> Content
    
    private var spanSizeLookup: ((Item) -> Int)?
    private var onItemClick: ((Int, Item) -> Void)?
    private var showsScrollIndicator: Bool = false
    private var verticalLayout: RecyclerViewVerticalLayout = .wrapContent
    private var withAnimation: Bool = true
    private var reverseLayout: Bool = false
    private var stackFromEnd: Bool = false
    private var pageSize: Int = 50
    private var onScroll: ((CGPoint) -> Void)?
    private var onLoadMore: ((Int, Int) -> Void)?
    private var withoutStatusBar: Bool = false
    
    private var processedData: [Item] {
        if stackFromEnd && !reverseLayout {
            return data.reversed()
        }
        return data
    }
    
    public init(data: [Item], layout: RecyclerViewLayoutManager, @ViewBuilder content: @escaping (Item) -> Content) {
        self.data = data
        self.layout = layout
        self.content = content
    }
    
    public func spanSizeLookup(_ lookup: @escaping (Item) -> Int) -> Self {
        var copy = self
        copy.spanSizeLookup = lookup
        return copy
    }
    
    public func onItemClick(_ click: @escaping (Int, Item) -> Void) -> Self {
        var copy = self
        copy.onItemClick = click
        return copy
    }
    
    public func showsScrollIndicator(_ show: Bool) -> Self {
        var copy = self
        copy.showsScrollIndicator = show
        return copy
    }
    
    public func verticalLayout(_ verticalLayout: RecyclerViewVerticalLayout) -> Self {
        var copy = self
        copy.verticalLayout = verticalLayout
        return copy
    }
    
    public func withAnimation(_ enabled: Bool) -> Self {
        var copy = self
        copy.withAnimation = enabled
        return copy
    }
    
    public func reverseLayout(_ enabled: Bool) -> Self {
        var copy = self
        copy.reverseLayout = enabled
        return copy
    }
    
    public func stackFromEnd(_ enabled: Bool) -> Self {
        var copy = self
        copy.stackFromEnd = enabled
        return copy
    }
    
    public func onLoadMore(_ perform: @escaping (Int, Int) -> Void) -> Self {
        var copy = self
        copy.pageSize = 50
        copy.onLoadMore = perform
        return copy
    }
    
    public func onLoadMore(_ pageSize: Int, _ perform: @escaping (Int, Int) -> Void) -> Self {
        var copy = self
        copy.pageSize = pageSize
        copy.onLoadMore = perform
        return copy
    }
    
    public func onScroll(_ perform: @escaping (CGPoint) -> Void) -> Self {
        var copy = self
        copy.onScroll = perform
        return copy
    }
    
    public func withoutStatusBar(_ enabled: Bool = false) -> Self {
        var copy = self
        copy.withoutStatusBar = enabled
        return copy
    }
    
    @ViewBuilder
    public var body: some View {
        if verticalLayout == .wrapContent {
            mainViewContent
                .frame(height: calculateWrapHeight())
        } else {
            mainViewContent
        }
    }
    
    @ViewBuilder
    private var mainViewContent: some View {
        RecyclerViewRepresentable(
            data: processedData,
            layout: layout,
            content: content,
            spanSizeLookup: spanSizeLookup,
            onItemClick: { index, item in
                if self.stackFromEnd && !self.reverseLayout {
                    let originalIndex = self.data.count - 1 - index
                    self.onItemClick?(originalIndex, item)
                } else {
                    self.onItemClick?(index, item)
                }
            },
            showsScrollIndicator: showsScrollIndicator,
            withAnimation: withAnimation,
            reverseLayout: reverseLayout || stackFromEnd,
            stackFromEnd: stackFromEnd,
            pageSize: pageSize,
            onScroll: onScroll,
            onLoadMore: onLoadMore,
            verticalLayout: verticalLayout
        )
        .padding(.top, withoutStatusBar ? (Double(UIDevice.current.systemVersion) ?? 13.0 >= 15.0 ? -statusBarHeight : 0) : 0)
    }
    
    private func measureCellHeight(for item: Item, width: CGFloat?) -> CGFloat {
        let view = content(item)
        let targetWidth = width ?? 150
        
        let constrainedView = view.frame(width: targetWidth)
        let hc = UIHostingController(rootView: constrainedView)
        hc.view.backgroundColor = .clear
        
        let size = hc.view.sizeThatFits(CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude))
        return ceil(size.height)
    }
    
    private func calculateWrapHeight() -> CGFloat {
        guard !data.isEmpty else { return 0 }
        
        let screenWidth = Self.displaySize.width
        let screenHeight = Self.displaySize.height
        
        let topPadding = Self.statusBarHeight + 64.0 + 50
        let bottomPadding = Self.navBarHeight
        let headerHeight: CGFloat = 80
        let maxLimitHeight = screenHeight - topPadding - headerHeight - bottomPadding - 20
        
        switch layout {
        case .linear(let orientation, let spacing):
            if orientation == .horizontal {
                var maxCellHeight: CGFloat = 0
                var currentWidth: CGFloat = 0
                
                for item in data {
                    let cellHeight = measureCellHeight(for: item, width: nil)
                    maxCellHeight = max(maxCellHeight, cellHeight)
                    
                    let cellWidth: CGFloat = 150
                    currentWidth += cellWidth + spacing
                    if currentWidth >= screenWidth {
                        break
                    }
                }
                return min(maxCellHeight + 2 * spacing + 15, maxLimitHeight)
            } else {
                var totalHeight: CGFloat = 0
                for item in data {
                    let cellHeight = measureCellHeight(for: item, width: screenWidth)
                    totalHeight += cellHeight + spacing
                    if totalHeight + 2 * spacing >= maxLimitHeight {
                        return maxLimitHeight
                    }
                }
                if totalHeight > spacing {
                    totalHeight -= spacing
                }
                return min(totalHeight + 2 * spacing, maxLimitHeight)
            }
            
        case .grid(let spanCount, let spacing, let orientation):
            if orientation == .vertical {
                let rows = buildRows(spanCount: spanCount)
                var totalHeight: CGFloat = 0
                
                let columnWidth = (screenWidth - CGFloat(spanCount - 1) * spacing) / CGFloat(spanCount)
                
                for rowIndices in rows {
                    var maxRowCellHeight: CGFloat = 0
                    for index in rowIndices {
                        let item = data[index]
                        let itemSpan = spanSizeLookup?(item) ?? 1
                        let span = min(max(1, itemSpan), spanCount)
                        let cellWidth = CGFloat(span) * columnWidth + CGFloat(span - 1) * spacing
                        
                        let cellHeight = measureCellHeight(for: item, width: cellWidth)
                        maxRowCellHeight = max(maxRowCellHeight, cellHeight)
                    }
                    totalHeight += maxRowCellHeight + spacing
                    if totalHeight >= maxLimitHeight {
                        return maxLimitHeight
                    }
                }
                if totalHeight > spacing {
                    totalHeight -= spacing
                }
                return min(totalHeight, maxLimitHeight)
            } else {
                var maxCellHeight: CGFloat = 0
                let measureCount = min(data.count, spanCount * 2)
                for i in 0..<measureCount {
                    let cellHeight = measureCellHeight(for: data[i], width: nil)
                    maxCellHeight = max(maxCellHeight, cellHeight)
                }
                let totalHeight = CGFloat(spanCount) * maxCellHeight + CGFloat(spanCount - 1) * spacing
                return min(totalHeight, maxLimitHeight)
            }
        }
    }
    
    private func buildRows(spanCount: Int) -> [[Int]] {
        var rows: [[Int]] = []
        var currentRow: [Int] = []
        var remainingSpans = spanCount
        
        for index in 0..<data.count {
            let item = data[index]
            let itemSpan = spanSizeLookup?(item) ?? 1
            let span = min(max(1, itemSpan), spanCount)
            
            if span > remainingSpans {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                }
                remainingSpans = spanCount
            }
            
            currentRow.append(index)
            remainingSpans -= span
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}

struct RecyclerViewRepresentable<Item: Identifiable, Content: View>: UIViewRepresentable {
    typealias UIViewType = UIRecyclerView
    typealias Coordinator = RecyclerViewCoordinator<Item, Content>
    
    let data: [Item]
    let layout: RecyclerViewLayoutManager
    let content: (Item) -> Content
    let spanSizeLookup: ((Item) -> Int)?
    let onItemClick: ((Int, Item) -> Void)?
    let showsScrollIndicator: Bool
    let withAnimation: Bool
    let reverseLayout: Bool
    let stackFromEnd: Bool
    let pageSize: Int
    let onScroll: ((CGPoint) -> Void)?
    let onLoadMore: ((Int, Int) -> Void)?
    let verticalLayout: RecyclerViewVerticalLayout
    
    func makeCoordinator() -> Coordinator {
        return RecyclerViewCoordinator()
    }
    
    func makeUIView(context: Context) -> UIRecyclerView {
        let collectionView = UIRecyclerView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = verticalLayout == .matchParent ? .never : .automatic
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if reverseLayout {
            collectionView.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            collectionView.transform = .identity
        }
        CATransaction.commit()
        
        switch layout {
        case .linear(let orientation, _), .grid(_, _, let orientation):
            if orientation == .vertical {
                collectionView.showsVerticalScrollIndicator = showsScrollIndicator
                collectionView.showsHorizontalScrollIndicator = false
                collectionView.alwaysBounceVertical = true
                collectionView.alwaysBounceHorizontal = false
            } else {
                collectionView.showsVerticalScrollIndicator = false
                collectionView.showsHorizontalScrollIndicator = showsScrollIndicator
                collectionView.alwaysBounceVertical = false
                collectionView.alwaysBounceHorizontal = true
            }
        }
        
        let adapter = RecyclerViewAdapter<Item, Content>(collectionView: collectionView, content: content)
        adapter.reverseLayout = reverseLayout
        adapter.layout = layout
        adapter.pageSize = pageSize
        adapter.onScroll = onScroll
        adapter.onItemClick = onItemClick
        adapter.onLoadMore = onLoadMore
        adapter.items = data
        
        context.coordinator.adapter = adapter
        context.coordinator.lastData = data
        context.coordinator.lastLayout = layout
        
        let collectionViewLayout = makeCollectionViewLayout(adapter: adapter, layout: layout, spanSizeLookup: spanSizeLookup)
        collectionView.collectionViewLayout = collectionViewLayout
        
        return collectionView
    }
    
    func updateUIView(_ uiView: UIRecyclerView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if reverseLayout {
            uiView.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            uiView.transform = .identity
        }
        CATransaction.commit()
        
        let oldData = context.coordinator.lastData
        let newData = self.data
        context.coordinator.lastData = newData
        
        guard let adapter = context.coordinator.adapter else { return }
        adapter.content = self.content
        adapter.onItemClick = self.onItemClick
        adapter.reverseLayout = reverseLayout
        adapter.layout = self.layout
        adapter.pageSize = self.pageSize
        adapter.onScroll = self.onScroll
        adapter.onLoadMore = self.onLoadMore
        
        let layoutChanged = context.coordinator.lastLayout != self.layout
        context.coordinator.lastLayout = self.layout
        
        let oldIDs = oldData.map { $0.id }
        let newIDs = newData.map { $0.id }
        let dataChanged = oldIDs != newIDs
        
        let currentVersion = context.coordinator.updateVersion + 1
        context.coordinator.updateVersion = currentVersion
        
        switch layout {
        case .linear(let orientation, _), .grid(_, _, let orientation):
            if orientation == .vertical {
                uiView.showsVerticalScrollIndicator = showsScrollIndicator
            } else {
                uiView.showsHorizontalScrollIndicator = showsScrollIndicator
            }
        }
        
        if layoutChanged {
            adapter.items = newData
            let newLayout = makeCollectionViewLayout(adapter: adapter, layout: self.layout, spanSizeLookup: self.spanSizeLookup)
            uiView.setCollectionViewLayout(newLayout, animated: false)
            adapter.notifyDataSetChanged()
        } else if dataChanged {
            let capturedOldIDs = oldIDs
            let capturedNewIDs = newIDs
            let capturedNewData = newData
            
            DispatchQueue.global(qos: .userInteractive).async {
                let diff = capturedNewIDs.difference(from: capturedOldIDs)
                var insertions: [IndexPath] = []
                var deletions: [IndexPath] = []
                
                for change in diff {
                    switch change {
                    case .insert(let offset, _, _):
                        insertions.append(IndexPath(item: offset, section: 0))
                    case .remove(let offset, _, _):
                        deletions.append(IndexPath(item: offset, section: 0))
                    }
                }
                
                DispatchQueue.main.async {
                    guard let currentAdapter = context.coordinator.adapter,
                          context.coordinator.updateVersion == currentVersion else {
                        return
                    }
                    
                    if !insertions.isEmpty || !deletions.isEmpty {
                        let performUpdates = {
                            uiView.performBatchUpdates({
                                currentAdapter.items = capturedNewData
                                if !deletions.isEmpty {
                                    uiView.deleteItems(at: deletions)
                                }
                                if !insertions.isEmpty {
                                    uiView.insertItems(at: insertions)
                                }
                            }, completion: { _ in
                                uiView.collectionViewLayout.invalidateLayout()
                            })
                        }
                        
                        if self.withAnimation {
                            performUpdates()
                        } else {
                            UIView.performWithoutAnimation {
                                performUpdates()
                            }
                        }
                    } else {
                        currentAdapter.items = capturedNewData
                        currentAdapter.notifyDataSetChanged()
                        uiView.collectionViewLayout.invalidateLayout()
                    }
                }
            }
        } else {
            // Update visible cells in case content changed
            for cell in uiView.visibleCells {
                if let swiftUICell = cell as? ViewHolder<Content>,
                   let indexPath = uiView.indexPath(for: swiftUICell) {
                    if indexPath.item < adapter.items.count {
                        let item = adapter.items[indexPath.item]
                        let view = adapter.content(item)
                        let itemIDString = adapter.getItemIDString(for: item, at: indexPath.item)
                        swiftUICell.bind(view, itemID: itemIDString, parentViewController: adapter.parentViewController)
                    }
                }
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                if reverseLayout {
                    cell.transform = CGAffineTransform(rotationAngle: .pi)
                } else {
                    cell.transform = .identity
                }
                CATransaction.commit()
            }
            uiView.collectionViewLayout.invalidateLayout()
        }
    }
    
    private func makeCollectionViewLayout(adapter: RecyclerViewAdapter<Item, Content>, layout: RecyclerViewLayoutManager, spanSizeLookup: ((Item) -> Int)?) -> UICollectionViewLayout {
        let scrollDirection: UICollectionView.ScrollDirection
        switch layout {
        case .linear(let orientation, _):
            scrollDirection = orientation == .horizontal ? .horizontal : .vertical
        case .grid(_, _, let orientation):
            scrollDirection = orientation == .horizontal ? .horizontal : .vertical
        }
        
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = scrollDirection
        
        return UICollectionViewCompositionalLayout(sectionProvider: { [weak adapter] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let adapter = adapter else { return nil }
            let data = adapter.items
            
            switch layout {
            case .linear(let orientation, let spacing):
                if orientation == .vertical {
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(110)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let groupSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(110)
                    )
                    let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.interGroupSpacing = spacing
                    section.contentInsets = NSDirectionalEdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)
                    return section
                } else {
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .estimated(150),
                        heightDimension: .fractionalHeight(1.0)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let groupSize = NSCollectionLayoutSize(
                        widthDimension: .estimated(150),
                        heightDimension: .fractionalHeight(1.0)
                    )
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                    let section = NSCollectionLayoutSection(group: group)
                    section.interGroupSpacing = spacing
                    section.contentInsets = NSDirectionalEdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)
                    return section
                }
                
            case .grid(let spanCount, let spacing, let orientation):
                if data.isEmpty {
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(0.1)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                    return NSCollectionLayoutSection(group: group)
                }
                
                if orientation == .vertical {
                    if let spanSizeLookup = spanSizeLookup, spanCount > 1 {
                        var rows: [[Int]] = []
                        var currentRow: [Int] = []
                        var remainingSpans = spanCount
                        
                        let totalCount = data.count
                        for index in 0..<totalCount {
                            let item = data[index]
                            let itemSpan = spanSizeLookup(item)
                            let span = min(max(1, itemSpan), spanCount)
                            
                            if span > remainingSpans {
                                if !currentRow.isEmpty {
                                    rows.append(currentRow)
                                    currentRow = []
                                }
                                remainingSpans = spanCount
                            }
                            
                            currentRow.append(index)
                            remainingSpans -= span
                        }
                        if !currentRow.isEmpty {
                            rows.append(currentRow)
                        }
                        
                        var rowGroups: [NSCollectionLayoutItem] = []
                        for row in rows {
                            var subitems: [NSCollectionLayoutItem] = []
                            for index in row {
                                let item = data[index]
                                let itemSpan = spanSizeLookup(item)
                                let span = min(max(1, itemSpan), spanCount)
                                let fractionalWidth = CGFloat(span) / CGFloat(spanCount)
                                
                                let itemSize = NSCollectionLayoutSize(
                                    widthDimension: .fractionalWidth(fractionalWidth),
                                    heightDimension: .estimated(110)
                                )
                                let layoutItem = NSCollectionLayoutItem(layoutSize: itemSize)
                                subitems.append(layoutItem)
                            }
                            
                            let rowGroupSize = NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1.0),
                                heightDimension: .estimated(110)
                            )
                            
                            let rowGroup = NSCollectionLayoutGroup.horizontal(layoutSize: rowGroupSize, subitems: subitems)
                            rowGroup.interItemSpacing = .fixed(spacing)
                            rowGroups.append(rowGroup)
                        }
                        
                        if !rowGroups.isEmpty {
                            let rootGroupSize = NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1.0),
                                heightDimension: .estimated(110)
                            )
                            let rootGroup = NSCollectionLayoutGroup.vertical(layoutSize: rootGroupSize, subitems: rowGroups)
                            rootGroup.interItemSpacing = .fixed(spacing)
                            
                            let section = NSCollectionLayoutSection(group: rootGroup)
                            section.contentInsets = .zero
                            return section
                        }
                    }
                    
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(110)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    
                    let groupSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .estimated(110)
                    )
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: spanCount)
                    group.interItemSpacing = .fixed(spacing)
                    
                    let section = NSCollectionLayoutSection(group: group)
                    section.interGroupSpacing = spacing
                    section.contentInsets = .zero
                    return section
                } else {
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .fractionalHeight(1.0)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    
                    let groupSize = NSCollectionLayoutSize(
                        widthDimension: .estimated(100),
                        heightDimension: .fractionalHeight(1.0)
                    )
                    
                    let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitem: item, count: spanCount)
                    group.interItemSpacing = .fixed(spacing)
                    
                    let section = NSCollectionLayoutSection(group: group)
                    section.interGroupSpacing = spacing
                    section.contentInsets = .zero
                    return section
                }
            }
        }, configuration: configuration)
    }
}

public class RecyclerViewCoordinator<Item: Identifiable, Content: View> {
    var adapter: RecyclerViewAdapter<Item, Content>?
    var lastData: [Item] = []
    var lastLayout: RecyclerViewLayoutManager?
    var updateVersion: Int = 0
    
    public init() {}
}

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder?.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

extension UIHostingController {
    convenience public init(rootView: Content, ignoreSafeArea: Bool) {
        self.init(rootView: rootView)
        
        if ignoreSafeArea {
            disableSafeArea()
        }
    }
    
    func disableSafeArea() {
        guard let viewClass = object_getClass(view) else { return }
        
        let viewSubclassName = String(cString: class_getName(viewClass)).appending("_IgnoreSafeArea")
        if let viewSubclass = NSClassFromString(viewSubclassName) {
            object_setClass(view, viewSubclass)
        }
        else {
            guard let viewClassNameUtf8 = (viewSubclassName as NSString).utf8String else { return }
            guard let viewSubclass = objc_allocateClassPair(viewClass, viewClassNameUtf8, 0) else { return }
            
            if let method = class_getInstanceMethod(UIView.self, #selector(getter: UIView.safeAreaInsets)) {
                let safeAreaInsets: @convention(block) (AnyObject) -> UIEdgeInsets = { _ in
                    return .zero
                }
                class_addMethod(viewSubclass, #selector(getter: UIView.safeAreaInsets), imp_implementationWithBlock(safeAreaInsets), method_getTypeEncoding(method))
            }
            
            objc_registerClassPair(viewSubclass)
            object_setClass(view, viewSubclass)
        }
    }
}

extension Optional: @retroactive Identifiable where Wrapped: Identifiable {
    public var id: Wrapped.ID? {
        switch self {
        case .some(let value):
            return value.id
        case .none:
            return nil
        }
    }
}
