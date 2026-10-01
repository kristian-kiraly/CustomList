//
//  CustomList.swift
//
//
//  Created by Kristian Kiraly on 10/21/22.
//

import SwiftUI
import SwipeActions

public enum CellButtons: String, Identifiable {
    case edit = "Edit"
    case delete = "Delete"
    case save = "Save"
    case info = "Info"
    
    public var id: String {
        self.rawValue
    }
    
    public var backgroundColor: Color {
        switch self {
        case .edit:
            return .pink
        case .delete:
            return .red
        case .save:
            return .blue
        case .info:
            return .green
        }
    }
}

public extension View {
    @available(*, deprecated, message: "Will only support trailing buttons to accommodate swipe gestures. Use .addSwipeAction() in the future instead")
    @ViewBuilder
    func addButtonActions(leadingButtons: [CellButtons], trailingButton: [CellButtons], onClick: @escaping (CellButtons) -> Void) -> some View {
        let buttons = (leadingButtons + trailingButton).map { button in
            SwipeAction(name: button.rawValue, backgroundColor: button.backgroundColor, action: {onClick(button)})
        }
        self.addSwipeActions(buttons)
    }
}

public struct CustomList<T: CustomListCompatible, Content: View>: View {
    @Binding public var list: [T]
    public var allowsReordering: Bool = true
    public var isLazy: Bool = true
    public var tappedRowForItem: (Binding<T>) -> ()
    public var leftLabelString: (T) -> String
    public var rightLabelString: (T) -> String
    @ViewBuilder public var rowBuilder: ([T], Binding<T>, Int) -> Content
    @State private var useDefaultRowBuilder = false
    @State private var draggedItem: T?
    @State private var swipeDrawerOpen = false
    
    public init(
        list: Binding<[T]>,
        tappedRowForItem: @escaping (Binding<T>) -> () = { _ in },
        leftLabelString: @escaping (T) -> String = { _ in "Left" },
        rightLabelString: @escaping (T) -> String = { _ in "Right" },
        allowsReordering: Bool = true,
        isLazy: Bool = true,
        @ViewBuilder rowBuilder: @escaping ([T], Binding<T>, Int) -> Content
    ) {
        self._list = list
        self.allowsReordering = allowsReordering
        self.isLazy = isLazy
        self.tappedRowForItem = tappedRowForItem
        self.leftLabelString = leftLabelString
        self.rightLabelString = rightLabelString
        self.rowBuilder = rowBuilder
    }
    
    public var body: some View {
        Group {
            if isLazy {
                LazyVStack(spacing:0) {
                    listSection
                }
            } else {
                VStack(spacing: 0) {
                    listSection
                }
            }
        }
        // Suspend reorder drags while any swipe-actions drawer is open.
        .onPreferenceChange(SwipeActionsDrawerOpenPreferenceKey.self) { swipeDrawerOpen = $0 }
    }
    
    private func indexOfItem(item: T) -> Int {
        guard let index = list.firstIndex(where: { $0.id == item.id}) else { fatalError("No item with matching id found") }
        return index
    }
    
    private func setItem(item: T) {
        list[indexOfItem(item: item)] = item
    }
    
    private func underlyingItemForItem(item: T) -> T {
        guard let underlyingItem = list.first(where: {$0.id == item.id}) else { fatalError("No item with matching id found")}
        return underlyingItem
    }
    
    private var listSection: some View {
        ForEach(list) { item in
            let index = indexOfItem(item: item)
            let item = Binding { underlyingItemForItem(item: item) } set: { setItem(item: $0) }
            Group {
                // Note: the if/else below must only depend on allowsReordering
                // (fixed at init). Gating on the drawer-open preference here
                // would swap the row's view hierarchy every time a drawer
                // opens/closes and reset the rows' state (including the open
                // drawer itself).
                //
                // While any drawer is open, a high-priority long-press on every
                // row swallows the press so no reorder drag can start list-wide.
                // The mask is just a parameter (no structural change), so row
                // state is preserved. It fails on movement, so scrolling still
                // works. The drop delegate's isEnabled is a backstop.
                if allowsReordering {
                    rowDecider(list: list, item: item, index: index)
                        .onDrag {
                            self.draggedItem = item.wrappedValue
                            return NSItemProvider(item: nil, typeIdentifier: T.dragIdentifier)
                        }
                        .onDrop(of: [.data], delegate: CustomListDropDelegate(item: item.wrappedValue, items: $list, draggedItem: $draggedItem, isEnabled: allowsReordering && !swipeDrawerOpen))
                        .highPriorityGesture(
                            LongPressGesture(minimumDuration: 0.25).onEnded { _ in },
                            including: swipeDrawerOpen ? .all : .none
                        )
                } else {
                    rowDecider(list: list, item: item, index: index)
                }
            }
            .id(item.wrappedValue.id)
            .onTapGesture {
                tappedRowForItem(item)
            }
            .contentShape(Rectangle())
            .background {
                GeometryReader { geo in
                    Color(UIColor.systemBackground)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .animation(.default, value: list)
    }
    
    @ViewBuilder
    private func rowDecider(list: [T], item: Binding<T>, index: Int) -> some View {
        if useDefaultRowBuilder {
            defaultRowBuilder(index: index)
        } else {
            rowBuilder(list, item, index)
                .contentShape(Rectangle())
        }
    }
    
    @ViewBuilder
    private func defaultRowBuilder(index: Int) -> some View {
        let item = list[index]
        ZStack {
            Rectangle()
                .foregroundColor(Color(uiColor: .systemBackground))
            VStack(spacing: 0) {
                HStack {
                    Text(leftLabelString(item))
                        .fontWeight(.bold)
                    Spacer()
                    Text(rightLabelString(item))
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                if index != list.count - 1 { //If index isn't at the end of the list
                    Divider()
                        .padding(.leading, 25)
                }
            }
        }
    }
}

public extension CustomList where Content == EmptyView {
    init(list: Binding<[T]>,
         tappedRowForItem: @escaping (Binding<T>) -> () = { _ in },
         leftLabelString: @escaping (T) -> String = { _ in "Left" },
         rightLabelString: @escaping (T) -> String = { _ in "Right" },
         allowsReordering: Bool = true,
         isLazy: Bool = true
    ) {
        self.init(list:list, tappedRowForItem: tappedRowForItem, leftLabelString: leftLabelString, rightLabelString: rightLabelString, allowsReordering:allowsReordering, isLazy: isLazy, rowBuilder: { _, _, _ in EmptyView() })
        self.useDefaultRowBuilder = true
    }
}

public protocol CustomListCompatible: Equatable, Identifiable {
    static var dragIdentifier:String { get } //"get" is so it's read-only
}

fileprivate struct CustomListDropDelegate<T: Equatable> : DropDelegate {
    let item : T
    @Binding var items : [T]
    @Binding var draggedItem : T?
    var isEnabled : Bool = true

    func performDrop(info: DropInfo) -> Bool {
        return isEnabled
    }

    func dropEntered(info: DropInfo) {
        guard isEnabled else { return }
        guard let draggedItem = self.draggedItem else {
            return
        }

        if draggedItem != item {
            guard
                let from = items.firstIndex(of: draggedItem),
                let to = items.firstIndex(of: item) else {
                return
            }
            withAnimation(.default) {
                self.items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return isEnabled ? DropProposal(operation: .move) : nil
    }
}
