//
//  TabEditorView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/3/21.
//

import SwiftUI

struct TabEditorView: View {
    
    // Save data variables
    @EnvironmentObject var sessionData: SessionData {
        didSet {
            if sessionData.tabs.count == 1 {
                editMode = EditMode.inactive
            }
        }
    }
    
    // Variables
    @State private var editMode = EditMode.inactive
    @State var showingTabAdder = false
    
    var body: some View {
        
//        NavigationView {
            
            Form {
                
                Section(footer: Text("You can add up to five tabs to the quick access bar. The first tab in the list will be the default screen when the app is opened. If you choose to have only one tab, the quick access bar will not appear.")) {
                    
                    ForEach(sessionData.tabs, id: \.self) { tab in
                        
                        Text(tab)
                        
                    }
                    .onDelete(perform: onDelete)
                    .onMove(perform: onMove)
                    
                    if editMode == .inactive && sessionData.tabs.count < 5 {
                        Button(action: {
                            onAdd()
                        }) {
                            Text("Add Tab...")
                        }
                        .sheet(isPresented: $showingTabAdder) {
                            TabAdderView().environmentObject(sessionData)
                                .onDisappear {
                                    // Save the tab data
                                    UserDefaults.standard.set(sessionData.tabs, forKey: "Tabs")
                                    print("Tab data saved!")
                                }
                        }
                    }
                    
                }
                
            }
            
            .navigationBarItems(trailing: sessionData.tabs.count != 1 ? EditButton().isHidden(false) : EditButton().isHidden(true, remove: true))
            .navigationBarTitle(Text("Quick Access Tabs"), displayMode: .inline)
            .environment(\.editMode, $editMode)
//        }
        
    }
    
    private var addButton: some View {
        switch editMode {
        case .active:
            return AnyView(Button(action: onAdd) { Image(systemName: "plus") })
        default:
            return AnyView(EmptyView())
        }
    }
    
    // Functions
    func onAdd() {
        showingTabAdder.toggle()
    }
    
    private func onDelete(offsets: IndexSet) {
        sessionData.tabs.remove(atOffsets: offsets)
    }
    
    private func onMove(source: IndexSet, destination: Int) {
        sessionData.tabs.move(fromOffsets: source, toOffset: destination)
    }
    
}

//struct TabEditorView_Previews: PreviewProvider {
//    static var previews: some View {
//        TabEditorView()
//    }
//}

extension View {
    
    /// Hide or show the view based on a boolean value.
    ///
    /// Example for visibility:
    /// ```
    /// Text("Label")
    ///     .isHidden(true)
    /// ```
    ///
    /// Example for complete removal:
    /// ```
    /// Text("Label")
    ///     .isHidden(true, remove: true)
    /// ```
    ///
    /// - Parameters:
    ///   - hidden: Set to `false` to show the view. Set to `true` to hide the view.
    ///   - remove: Boolean value indicating whether or not to remove the view.
    @ViewBuilder func isHidden(_ hidden: Bool, remove: Bool = false) -> some View {
        if hidden {
            if !remove {
                self.hidden()
            }
        } else {
            self
        }
    }
}
