//
//  TypeDetailView.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/16/20.
//

import SwiftUI

struct TypeDetailView: View {
    
    // Variables
    var type: Type
    var type2: Type?
    @State var pickerChoice = 0
    var options = ["Defense", "Attack"]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        NavigationView {
            ScrollView {
                VStack {
                    
                    // HStack for the type indicators
                    HStack {
                        
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            ZStack {
                                
                                Circle()
                                    .foregroundColor(typeColorDelegator(type: type.name))
                                    .frame(width: 150, height: 150)
                                
                                Text(type.name.uppercased())
                                    .font(Font.custom("Andale Mono", size: 30))
                                    .foregroundColor(Color.white)
                                
                            }
                        }
                        
                        if let unwrapped = type2 {
                            NavigationLink(destination: TypeDetailViewN(type: unwrapped)) {
                                ZStack {
                                    
                                    Circle()
                                        .foregroundColor(typeColorDelegator(type: unwrapped.name))
                                        .frame(width: 150, height: 150)
                                    
                                    Text(unwrapped.name.uppercased())
                                        .font(Font.custom("Andale Mono", size: 30))
                                        .foregroundColor(Color.white)
                                    
                                }
                            }

                        }
                        
                    }
                    .padding(.top)
                    
                    // This picker only appears for single types and allows one to change between viewing defense information and viewing attack information. The default is defense.
                    if type2 == nil {
                        Picker(selection: $pickerChoice, label: Text("")) {
                            ForEach(0..<options.count) {
                                Text(self.options[$0])
                            }
                        }
                        .padding([.top, .leading, .trailing])
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // The following is for the defense section. It includes information on the type or dual type's hyperweaknesses, weaknesses, resistances, hyperresistances, and immunities, in that order.
                    
                    // Defense report No. 1 - Single Type
                    if pickerChoice == 0  && type2 == nil {

                        if type.weaknesses.count != 0 {
                            HStack {
                                Text("Weaknesses")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: Type.toType(list: type.weaknesses))
                                .padding(.leading)
                        }
                        
                        if type.resistances.count != 0 {
                            HStack {
                                Text("Resistantces")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: Type.toType(list: type.resistances))
                                .padding(.leading)
                        }
                        
                        if type.immunities.count != 0 {
                            HStack {
                                Text("Immunities")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: Type.toType(list: type.immunities))
                                .padding(.leading)
                        }
                        
                    // Defense report No. 2 - Dual Type
                    } else if pickerChoice == 0 && type2 != nil {
                        
                        if DualTypeEngine.hyperweak(type1: type, type2: type2!).count != 0 {
                            
                            HStack {
                                Text("Hyperweaknesses")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: DualTypeEngine.hyperweak(type1: type, type2: type2!))
                                .padding(.leading)
                            
                        }
                        
                        if DualTypeEngine.weak(type1: type, type2: type2!).count != 0 {
                            HStack {
                                Text("Weaknesses")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: DualTypeEngine.weak(type1: type, type2: type2!))
                                .padding(.leading)
                        }
                        
                        if DualTypeEngine.resistant(type1: type, type2: type2!).count != 0 {
                            HStack {
                                Text("Resistances")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: DualTypeEngine.resistant(type1: type, type2: type2!))
                                .padding(.leading)
                        }
                        
                        if DualTypeEngine.hyperresistant(type1: type, type2: type2!).count != 0 {
                            HStack {
                                Text("Hyperresistances")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: DualTypeEngine.hyperresistant(type1: type, type2: type2!))
                                .padding(.leading)
                        }
                        
                        if DualTypeEngine.immune(type1: type, type2: type2!).count != 0 {
                            HStack {
                                Text("Immunities")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: DualTypeEngine.immune(type1: type, type2: type2!))
                                .padding(.leading)
                        }
                        
                    } else if pickerChoice == 1 && type2 == nil {
                        
                        if type.superEffective.count != 0 {
                            HStack {
                                Text("Super Effective")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: Type.toType(list: type.superEffective))
                                .padding(.leading)
                        }
                        
                        if type.notVeryEffective.count != 0 {
                            HStack {
                                Text("Not Very Effective")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: Type.toType(list: type.notVeryEffective))
                                .padding(.leading)
                        }
                        
                        if type.noEffect.count != 0 {
                            HStack {
                                Text("No Effect")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.leading)
                            .padding(.top)
                            
                            TypeList(types: Type.toType(list: type.noEffect))
                                .padding(.leading)
                        }
                        
                    }
                    
                    Spacer()
                    
                }
                .padding(.bottom)
            }
            
            .navigationBarTitle(Text(""), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done").foregroundColor(Color.blue) })
        }
        
    }
}

struct TypeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TypeDetailView(type: Type.typeLookup(name: "Grass")!)
    }
}

struct TypeList: View {
    
    // Variables
    var types: [Type]
    
    var body: some View {
        
        if types.count > 9 {
            VStack(alignment: .leading) {
                HStack {
                    ForEach(types[0...2], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    Spacer()
                }
                HStack {
                    ForEach(types[3...5], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    Spacer()
                }
                HStack {
                    ForEach(types[6...8], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    Spacer()
                }
                HStack {
                    ForEach(types[9...(types.count - 1)], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    Spacer()
                }
            }
        } else if types.count > 6 {
            
            VStack(alignment: .leading) {
                HStack {
                    ForEach(types[0...2], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    
                    if types.count - 3 == -2 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    } else if types.count - 3 == -1 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    }
                    
                    Spacer()
                }
                HStack {
                    ForEach(types[3...5], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    
                    if types.count - 6 == -2 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    } else if types.count - 6 == -1 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    }
                    
                    Spacer()
                }
                HStack {
                    ForEach(types[6...(types.count - 1)], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    
                    if types.count - 9 == -2 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    } else if types.count - 9 == -1 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    }
                    
                    Spacer()
                }
            }
            
        } else if types.count > 3 {
            VStack(alignment: .leading) {
                HStack {
                    ForEach(types[0...2], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    
                    if types.count - 3 == -2 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    } else if types.count - 3 == -1 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    }
                    
                    Spacer()
                }
                HStack {
                    ForEach(types[3...(types.count - 1)], id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    
                    if types.count - 6 == -2 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    } else if types.count - 6 == -1 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    }
                    
                    Spacer()
                }
            }
        } else {
            VStack(alignment: .leading) {
                HStack {
                    ForEach(types, id: \.name) { type in
                        NavigationLink(destination: TypeDetailViewN(type: type)) {
                            WidthlessPokemonDetailTypeView(types: [type.name, ""])
                        }
                    }
                    
                    if types.count == 1 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    } else if types.count == 2 {
                        WidthlessPokemonDetailTypeView(types: ["Water", ""])
                            .hidden()
                    }
                    
                    Spacer()
                }
                
            }
        }
        
    }
    
}

struct TypeDetailViewN: View {
    
    // Variables
    var type: Type
    var type2: Type?
    @State var pickerChoice = 0
    var options = ["Defense", "Attack"]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
//        NavigationView {
        ScrollView {
            VStack {
                
                // HStack for the type indicators
                HStack {
                    
                    ZStack {
                        
                        Circle()
                            .foregroundColor(typeColorDelegator(type: type.name))
                            .frame(width: 150, height: 150)
                        
                        Text(type.name.uppercased())
                            .font(Font.custom("Andale Mono", size: 30))
                            .foregroundColor(Color.white)
                        
                    }
                    
                    if let unwrapped = type2 {
                        ZStack {
                            
                            Circle()
                                .foregroundColor(typeColorDelegator(type: unwrapped.name))
                                .frame(width: 150, height: 150)
                            
                            Text(unwrapped.name.uppercased())
                                .font(Font.custom("Andale Mono", size: 30))
                                .foregroundColor(Color.white)
                            
                        }

                    }
                    
                }
                .padding(.top)
                
                // This picker only appears for single types and allows one to change between viewing defense information and viewing attack information. The default is defense.
                if type2 == nil {
                    Picker(selection: $pickerChoice, label: Text("")) {
                        ForEach(0..<options.count) {
                            Text(self.options[$0])
                        }
                    }
                    .padding([.top, .leading, .trailing])
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // The following is for the defense section. It includes information on the type or dual type's hyperweaknesses, weaknesses, resistances, hyperresistances, and immunities, in that order.
                
                // Defense report No. 1 - Single Type
                if pickerChoice == 0  && type2 == nil {

                    if type.weaknesses.count != 0 {
                        HStack {
                            Text("Weaknesses")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: Type.toType(list: type.weaknesses))
                            .padding(.leading)
                    }
                    
                    if type.resistances.count != 0 {
                        HStack {
                            Text("Resistantces")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: Type.toType(list: type.resistances))
                            .padding(.leading)
                    }
                    
                    if type.immunities.count != 0 {
                        HStack {
                            Text("Immunities")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: Type.toType(list: type.immunities))
                            .padding(.leading)
                    }
                    
                // Defense report No. 2 - Dual Type
                } else if pickerChoice == 0 && type2 != nil {
                    
                    if DualTypeEngine.hyperweak(type1: type, type2: type2!).count != 0 {
                        
                        HStack {
                            Text("Hyperweaknesses")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: DualTypeEngine.hyperweak(type1: type, type2: type2!))
                            .padding(.leading)
                        
                    }
                    
                    if DualTypeEngine.weak(type1: type, type2: type2!).count != 0 {
                        HStack {
                            Text("Weaknesses")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: DualTypeEngine.weak(type1: type, type2: type2!))
                            .padding(.leading)
                    }
                    
                    if DualTypeEngine.resistant(type1: type, type2: type2!).count != 0 {
                        HStack {
                            Text("Resistances")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: DualTypeEngine.resistant(type1: type, type2: type2!))
                            .padding(.leading)
                    }
                    
                    if DualTypeEngine.hyperresistant(type1: type, type2: type2!).count != 0 {
                        HStack {
                            Text("Hyperresistances")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: DualTypeEngine.hyperresistant(type1: type, type2: type2!))
                            .padding(.leading)
                    }
                    
                    if DualTypeEngine.immune(type1: type, type2: type2!).count != 0 {
                        HStack {
                            Text("Immunities")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: DualTypeEngine.immune(type1: type, type2: type2!))
                            .padding(.leading)
                    }
                    
                } else if pickerChoice == 1 && type2 == nil {
                    
                    if type.superEffective.count != 0 {
                        HStack {
                            Text("Super Effective")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: Type.toType(list: type.superEffective))
                            .padding(.leading)
                    }
                    
                    if type.notVeryEffective.count != 0 {
                        HStack {
                            Text("Not Very Effective")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: Type.toType(list: type.notVeryEffective))
                            .padding(.leading)
                    }
                    
                    if type.noEffect.count != 0 {
                        HStack {
                            Text("No Effect")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.leading)
                        .padding(.top)
                        
                        TypeList(types: Type.toType(list: type.noEffect))
                            .padding(.leading)
                    }
                    
                }
                
                Spacer()
                
            }
        }
            
//            .navigationBarTitle(Text(""), displayMode: .inline)
//            .navigationBarItems(trailing: Button(action: { self.presentationMode.wrappedValue.dismiss() }) { Text("Done").foregroundColor(Color.blue) })
//        }
        
    }
}
