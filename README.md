# CustomList

Creating an alternative to List that doesn't crash when using ScrollViewProxy three times in a row. It allows fully customized cell generation, adding swipe actions, and dragging to reorder

Usage:

```swift
struct ContentView: View {
    @State var testList = [...]
    
    var body: some View {
        CustomList(list: $testList)  { list, item, index in
            row(list: list, item: item, index: index)
        }
    }
        
    func row(list:[TestStruct], item:TestStruct, index:Int) -> some View {
        Text(item)
        .addButtonActions(leadingButtons: [], trailingButton: [.delete]) { button in
            print(button)
        }
    }
```
