import SwiftUI

public struct CustomList<T:CustomListCompatible, Content>: View where Content: View {
    @Binding public var list:[T]
    public var allowsReordering:Bool = true
    public var tappedRowForItem:(Binding<T>) -> () = {item in print("Editing \(item)")}
    public var leftLabelString:(T) -> String = {_ in return "Left"}
    public var rightLabelString:(T) -> String = {_ in return "Right"}
    @ViewBuilder public var rowBuilder:([T], Binding<T>, Int) -> Content
    @State private var useDefaultRowBuilder = false
    @State private var draggedItem: T?
    
    
    public init(list:Binding<[T]>, tappedRowForItem:@escaping (Binding<T>) -> () = {_ in }, leftLabelString:@escaping (T) -> String = {_ in "Left"}, rightLabelString:@escaping (T) -> String = {_ in "Right"}, allowsReordering:Bool = true, rowBuilder:@escaping ([T], Binding<T>, Int) -> Content) {
        self._list = list
        self.allowsReordering = allowsReordering
        self.tappedRowForItem = tappedRowForItem
        self.leftLabelString = leftLabelString
        self.rightLabelString = rightLabelString
        self.rowBuilder = rowBuilder
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing:0) {
                ForEach($list, id: \.id) { $item in
                    if let index = list.firstIndex(of: item) {
                        rowDecider(list: list, item: $item, index: index)
                            .onTapGesture {
                                tappedRowForItem($item)
                            }
                            .if(allowsReordering) { view in
                                view.onDrag {
                                    withAnimation {
                                        self.draggedItem = item
                                        return NSItemProvider(item: nil, typeIdentifier: T.dragIdentifier)
                                    }
                                }
                                .onDrop(of: [.data], delegate: CustomListDropDelegate(item: item, items: $list, draggedItem: $draggedItem))
                            }
                            .contentShape(Rectangle())
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func rowDecider(list:[T], item:Binding<T>, index:Int) -> some View {
        if useDefaultRowBuilder {
            defaultRowBuilder(list: list, item: item, index: index)
        } else {
            rowBuilder(list, item, index)
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
    init(list:Binding<[T]>, tappedRowForItem:@escaping (Binding<T>) -> () = {_ in }, leftLabelString:@escaping (T) -> String = {_ in "Left"}, rightLabelString:@escaping (T) -> String = {_ in "Right"}, allowsReordering:Bool = true) {
        self.init(list:list, tappedRowForItem: tappedRowForItem, leftLabelString: leftLabelString, rightLabelString: rightLabelString, allowsReordering:allowsReordering, rowBuilder: { _,_,_ in EmptyView() })
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
