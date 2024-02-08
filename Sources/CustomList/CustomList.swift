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
    @available(*, deprecated, message: "Will only support trailing buttons to accommodate swipe gestures. Use .addSwipeAction(SwipeAction) in the future instead")
    @ViewBuilder
    func addButtonActions(leadingButtons: [CellButtons], trailingButton: [CellButtons], onClick: @escaping (CellButtons) -> Void) -> some View {
        let buttons = (leadingButtons + trailingButton).map { button in
            SwipeAction(name: button.rawValue, action: {onClick(button)}, backgroundColor: button.backgroundColor)
        }
        self.addSwipeActions(buttons)
    }
}

public struct CustomList<T: CustomListCompatible, Content: View>: View {
    @Binding public var list: [T]
    public var allowsReordering: Bool
    public var isLazy:Bool
    public var tappedRowForItem: (Binding<T>) -> ()
    public var leftLabelString: (T) -> String
    public var rightLabelString: (T) -> String
    @ViewBuilder public var rowBuilder: ([T], Binding<T>, Int) -> Content
    @State private var useDefaultRowBuilder = false
    @State private var draggedItem: T?
    
    @State private var localList: [T]
    
    public init(list:Binding<[T]>, tappedRowForItem:@escaping (Binding<T>) -> () = {_ in }, leftLabelString:@escaping (T) -> String = {_ in "Left"}, rightLabelString:@escaping (T) -> String = {_ in "Right"}, allowsReordering:Bool = true, isLazy:Bool = true, @ViewBuilder rowBuilder:@escaping ([T], Binding<T>, Int) -> Content) {
        self._list = list
        self._localList = State(initialValue: list.wrappedValue)
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
        .onChange(of: list) { newValue in
            localList = newValue
        }
        .onChange(of: localList) { newValue in
            guard newValue != list else { return }
            list = newValue
        }
    }
    
    private var listSection: some View {
        ForEach(Array($localList.enumerated()), id:\.element.id) { index, $item in
            rowDecider(list: localList, item: $item, index: index)
                .onTapGesture {
                    tappedRowForItem($item)
                }
                .if(allowsReordering) { view in
                    view.onDrag {
                        self.draggedItem = item
                        return NSItemProvider(item: nil, typeIdentifier: T.dragIdentifier)
                    }
                    .onDrop(of: [.data], delegate: CustomListDropDelegate(item: item, items: $localList, draggedItem: $draggedItem))
                }
                .contentShape(Rectangle())
                .background {
                    GeometryReader { geo in
                        Color(UIColor.systemBackground)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
        }
        .animation(.default, value: localList)
    }
    
    @ViewBuilder
    private func rowDecider(list:[T], item:Binding<T>, index:Int) -> some View {
        if useDefaultRowBuilder {
            defaultRowBuilder(list: list, item: item, index: index)
        } else {
            rowBuilder(list, item, index)
                .contentShape(Rectangle())
        }
    }
    
    private func defaultRowBuilder(list:[T], item:Binding<T>, index:Int) -> some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color(uiColor: .systemBackground))
            VStack(spacing: 0) {
                HStack {
                    Text(leftLabelString(item.wrappedValue))
                        .fontWeight(.bold)
                    Spacer()
                    Text(rightLabelString(item.wrappedValue))
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
    init(list:Binding<[T]>, tappedRowForItem:@escaping (Binding<T>) -> () = {_ in }, leftLabelString:@escaping (T) -> String = {_ in "Left"}, rightLabelString:@escaping (T) -> String = {_ in "Right"}, allowsReordering:Bool = true, isLazy:Bool = true) {
        self.init(list:list, tappedRowForItem: tappedRowForItem, leftLabelString: leftLabelString, rightLabelString: rightLabelString, allowsReordering:allowsReordering, isLazy: isLazy, rowBuilder: { _,_,_ in EmptyView() })
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

    func performDrop(info: DropInfo) -> Bool {
        return true
    }

    func dropEntered(info: DropInfo) {
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
        return DropProposal(operation: .move)
    }
}

private extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
