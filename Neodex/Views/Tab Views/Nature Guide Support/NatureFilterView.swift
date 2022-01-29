//
//  NatureFilterView.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/27/21.
//

import SwiftUI

struct NatureFilterView: View {
    
    // Filter variables
    @Binding var plusFilters: [String]
    @Binding var minusFilters: [String]
    @Binding var likesFilters: [String]
    @Binding var dislikesFilters: [String]
    @Binding var confusingBerryFilters: [String]
    
    // Variables
    @State var showingBerryPicker = false
    @Binding var filterResults: Int
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                VStack {
                    
                    // Ex. argument stack
                    VStack {
                        
                        HeadingText(text: "Increased Stat")
                            .padding(.top)
                        
                        HStack {
                            
                            VStack {
                                Button(action: {
                                    if plusFilters.contains("Attack") {
                                        plusFilters = plusFilters.filter({ $0 != "Attack" })
                                    } else if plusFilters.count == 1 {
                                        plusFilters.removeAll()
                                        plusFilters.append("Attack")
                                    } else {
                                        plusFilters.append("Attack")
                                    }
                                }) {
                                    FilterOptionView(imageName: "burst.fill", filterName: "Attack", color: plusFilters.contains("Attack") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if plusFilters.contains("Sp. Atk") {
                                        plusFilters = plusFilters.filter({ $0 != "Sp. Atk" })
                                    } else if plusFilters.count == 1 {
                                        plusFilters.removeAll()
                                        plusFilters.append("Sp. Atk")
                                    } else {
                                        plusFilters.append("Sp. Atk")
                                    }
                                }) {
                                    FilterOptionView(imageName: "bolt.circle.fill", filterName: "Special Attack", color: plusFilters.contains("Sp. Atk") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if plusFilters.contains("Speed") {
                                        plusFilters = plusFilters.filter({ $0 != "Speed" })
                                    } else if plusFilters.count == 1 {
                                        plusFilters.removeAll()
                                        plusFilters.append("Speed")
                                    } else {
                                        plusFilters.append("Speed")
                                    }
                                }) {
                                    FilterOptionView(imageName: "hare.fill", filterName: "Speed", color: plusFilters.contains("Speed") ? .blue : .secondary)
                                }
                            }
                            VStack {
                                Button(action: {
                                    if plusFilters.contains("Defense") {
                                        plusFilters = plusFilters.filter({ $0 != "Defense" })
                                    } else if plusFilters.count == 1 {
                                        plusFilters.removeAll()
                                        plusFilters.append("Defense")
                                    } else {
                                        plusFilters.append("Defense")
                                    }
                                }) {
                                    FilterOptionView(imageName: "shield.fill", filterName: "Defense", color: plusFilters.contains("Defense") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if plusFilters.contains("Sp. Def") {
                                        plusFilters = plusFilters.filter({ $0 != "Sp. Def" })
                                    } else if plusFilters.count == 1 {
                                        plusFilters.removeAll()
                                        plusFilters.append("Sp. Def")
                                    } else {
                                        plusFilters.append("Sp. Def")
                                    }
                                }) {
                                    FilterOptionView(imageName: "shield.checkerboard", filterName: "Special Defense", color: plusFilters.contains("Sp. Def") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if plusFilters.contains("Attack") {
                                        plusFilters = plusFilters.filter({ $0 != "Attack" })
                                    } else if plusFilters.count == 1 {
                                        plusFilters.removeAll()
                                        plusFilters.append("Attack")
                                    } else {
                                        plusFilters.append("Attack")
                                    }
                                }) {
                                    FilterOptionView(imageName: "burst.fill", filterName: "Attack", color: plusFilters.contains("Attack") ? .blue : .secondary)
                                }
                                .hidden()
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        HeadingText(text: "Decreased Stat")
                            .padding(.top)
                        
                        HStack {
                            
                            VStack {
                                Button(action: {
                                    if minusFilters.contains("Attack") {
                                        minusFilters = minusFilters.filter({ $0 != "Attack" })
                                    } else if minusFilters.count == 1 {
                                        minusFilters.removeAll()
                                        minusFilters.append("Attack")
                                    } else {
                                        minusFilters.append("Attack")
                                    }
                                }) {
                                    FilterOptionView(imageName: "burst.fill", filterName: "Attack", color: minusFilters.contains("Attack") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if minusFilters.contains("Sp. Atk") {
                                        minusFilters = minusFilters.filter({ $0 != "Sp. Atk" })
                                    } else if minusFilters.count == 1 {
                                        minusFilters.removeAll()
                                        minusFilters.append("Sp. Atk")
                                    } else {
                                        minusFilters.append("Sp. Atk")
                                    }
                                }) {
                                    FilterOptionView(imageName: "bolt.circle.fill", filterName: "Special Attack", color: minusFilters.contains("Sp. Atk") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if minusFilters.contains("Speed") {
                                        minusFilters = minusFilters.filter({ $0 != "Speed" })
                                    } else if minusFilters.count == 1 {
                                        minusFilters.removeAll()
                                        minusFilters.append("Speed")
                                    } else {
                                        minusFilters.append("Speed")
                                    }
                                }) {
                                    FilterOptionView(imageName: "hare.fill", filterName: "Speed", color: minusFilters.contains("Speed") ? .blue : .secondary)
                                }

                            }
                            VStack {
                                Button(action: {
                                    if minusFilters.contains("Defense") {
                                        minusFilters = minusFilters.filter({ $0 != "Defense" })
                                    } else if minusFilters.count == 1 {
                                        minusFilters.removeAll()
                                        minusFilters.append("Defense")
                                    } else {
                                        minusFilters.append("Defense")
                                    }
                                }) {
                                    FilterOptionView(imageName: "shield.fill", filterName: "Defense", color: minusFilters.contains("Defense") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if minusFilters.contains("Sp. Def") {
                                        minusFilters = minusFilters.filter({ $0 != "Sp. Def" })
                                    } else if minusFilters.count == 1 {
                                        minusFilters.removeAll()
                                        minusFilters.append("Sp. Def")
                                    } else {
                                        minusFilters.append("Sp. Def")
                                    }
                                }) {
                                    FilterOptionView(imageName: "shield.checkerboard", filterName: "Special Defense", color: minusFilters.contains("Sp. Def") ? .blue : .secondary)
                                }
                                Button(action: {
                                    if minusFilters.contains("Speed") {
                                        minusFilters = minusFilters.filter({ $0 != "Speed" })
                                    } else if minusFilters.count == 1 {
                                        minusFilters.removeAll()
                                        minusFilters.append("Speed")
                                    } else {
                                        minusFilters.append("Speed")
                                    }
                                }) {
                                    FilterOptionView(imageName: "hare.fill", filterName: "Speed", color: minusFilters.contains("Speed") ? .blue : .secondary)
                                }
                                .hidden()
                            }
                            
                        }
                        .padding(.horizontal)
                        
                    }
                    
                    HeadingText(text: "Liked Berry Flavor")
                        .padding(.top)
                    
                    HStack {
                        
                        Button(action: {
                            if likesFilters.contains("Spicy") {
                                likesFilters = likesFilters.filter({ $0 != "Spicy" })
                            } else if likesFilters.count == 1 {
                                likesFilters.removeAll()
                                likesFilters.append("Spicy")
                            } else {
                                likesFilters.append("Spicy")
                            }
                        }) {
                            FilterOptionView(imageName: "flame.fill", filterName: "Spicy", color: likesFilters.contains("Spicy") ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            if likesFilters.contains("Dry") {
                                likesFilters = likesFilters.filter({ $0 != "Dry" })
                            } else if likesFilters.count == 1 {
                                likesFilters.removeAll()
                                likesFilters.append("Dry")
                            } else {
                                likesFilters.append("Dry")
                            }
                        }) {
                            FilterOptionView(imageName: "sun.max.fill", filterName: "Dry", color: likesFilters.contains("Dry") ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        
                        Button(action: {
                            if likesFilters.contains("Sweet") {
                                likesFilters = likesFilters.filter({ $0 != "Sweet" })
                            } else if likesFilters.count == 1 {
                                likesFilters.removeAll()
                                likesFilters.append("Sweet")
                            } else {
                                likesFilters.append("Sweet")
                            }
                        }) {
                            FilterOptionView(imageName: "sparkles", filterName: "Sweet", color: likesFilters.contains("Sweet") ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            if likesFilters.contains("Bitter") {
                                likesFilters = likesFilters.filter({ $0 != "Bitter" })
                            } else if likesFilters.count == 1 {
                                likesFilters.removeAll()
                                likesFilters.append("Bitter")
                            } else {
                                likesFilters.append("Bitter")
                            }
                        }) {
                            FilterOptionView(imageName: "aqi.high", filterName: "Bitter", color: likesFilters.contains("Bitter") ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        
                        Button(action: {
                            if likesFilters.contains("Sour") {
                                likesFilters = likesFilters.filter({ $0 != "Sour" })
                            } else if likesFilters.count == 1 {
                                likesFilters.removeAll()
                                likesFilters.append("Sour")
                            } else {
                                likesFilters.append("Sour")
                            }
                        }) {
                            FilterOptionView(imageName: "drop.fill", filterName: "Sour", color: likesFilters.contains("Sour") ? .blue : .secondary)
                        }
                        
                        Button(action: {
                            if likesFilters.contains("No Preference") {
                                likesFilters = likesFilters.filter({ $0 != "No Preference" })
                            } else if likesFilters.count == 1 {
                                likesFilters.removeAll()
                                likesFilters.append("No Preference")
                            } else {
                                likesFilters.append("No Preference")
                            }
                        }) {
                            FilterOptionView(imageName: "nosign", filterName: "No Preference", color: likesFilters.contains("No Preference") ? .blue : .secondary)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    HeadingText(text: "Disliked Berry Flavor")
                        .padding(.top)
                    
                    // EAS
                    VStack {
                        
                        HStack {
                            
                            Button(action: {
                                if dislikesFilters.contains("Spicy") {
                                    dislikesFilters = dislikesFilters.filter({ $0 != "Spicy" })
                                } else if dislikesFilters.count == 1 {
                                    dislikesFilters.removeAll()
                                    dislikesFilters.append("Spicy")
                                } else {
                                    dislikesFilters.append("Spicy")
                                }
                            }) {
                                FilterOptionView(imageName: "flame.fill", filterName: "Spicy", color: dislikesFilters.contains("Spicy") ? .blue : .secondary)
                            }
                            
                            Button(action: {
                                if dislikesFilters.contains("Dry") {
                                    dislikesFilters = dislikesFilters.filter({ $0 != "Dry" })
                                } else if dislikesFilters.count == 1 {
                                    dislikesFilters.removeAll()
                                    dislikesFilters.append("Dry")
                                } else {
                                    dislikesFilters.append("Dry")
                                }
                            }) {
                                FilterOptionView(imageName: "sun.max.fill", filterName: "Dry", color: dislikesFilters.contains("Dry") ? .blue : .secondary)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            
                            Button(action: {
                                if dislikesFilters.contains("Sweet") {
                                    dislikesFilters = dislikesFilters.filter({ $0 != "Sweet" })
                                } else if dislikesFilters.count == 1 {
                                    dislikesFilters.removeAll()
                                    dislikesFilters.append("Sweet")
                                } else {
                                    dislikesFilters.append("Sweet")
                                }
                            }) {
                                FilterOptionView(imageName: "sparkles", filterName: "Sweet", color: dislikesFilters.contains("Sweet") ? .blue : .secondary)
                            }
                            
                            Button(action: {
                                if dislikesFilters.contains("Bitter") {
                                    dislikesFilters = dislikesFilters.filter({ $0 != "Bitter" })
                                } else if dislikesFilters.count == 1 {
                                    dislikesFilters.removeAll()
                                    dislikesFilters.append("Bitter")
                                } else {
                                    dislikesFilters.append("Bitter")
                                }
                            }) {
                                FilterOptionView(imageName: "aqi.high", filterName: "Bitter", color: dislikesFilters.contains("Bitter") ? .blue : .secondary)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            
                            Button(action: {
                                if dislikesFilters.contains("Sour") {
                                    dislikesFilters = dislikesFilters.filter({ $0 != "Sour" })
                                } else if dislikesFilters.count == 1 {
                                    dislikesFilters.removeAll()
                                    dislikesFilters.append("Sour")
                                } else {
                                    dislikesFilters.append("Sour")
                                }
                            }) {
                                FilterOptionView(imageName: "drop.fill", filterName: "Sour", color: dislikesFilters.contains("Sour") ? .blue : .secondary)
                            }
                            
                            Button(action: {
                                if dislikesFilters.contains("No Preference") {
                                    dislikesFilters = dislikesFilters.filter({ $0 != "No Preference" })
                                } else if dislikesFilters.count == 1 {
                                    dislikesFilters.removeAll()
                                    dislikesFilters.append("No Preference")
                                } else {
                                    dislikesFilters.append("No Preference")
                                }
                            }) {
                                FilterOptionView(imageName: "nosign", filterName: "No Preference", color: dislikesFilters.contains("No Preference") ? .blue : .secondary)
                            }
                            
                        }
                        .padding(.horizontal)
                        
                    }
                    
                    HeadingText(text: "Confused By Berry")
                        .padding(.top)
                    
                    if confusingBerryFilters.isEmpty {
                        
                        HStack {
                            
                            Button(action: {
                                self.showingBerryPicker.toggle()
                            }) {
                                FilterOptionView(imageName: "plus", filterName: "Add Berry Filter", color: .secondary)
                            }
                            .sheet(isPresented: $showingBerryPicker) {
                                NatureBerryFilterPicker(confusingBerryFilters: $confusingBerryFilters)
                            }
                            
                            
                            FilterOptionView(imageName: "plus", filterName: "Add Berry Filter", color: .secondary)
                                .hidden()
                            
                        }
                        .padding(.horizontal)
                        
                    } else {
                        
                        HStack {
                            
                            Button(action: {
                                confusingBerryFilters.removeAll()
                            }) {
                                FilterOptionView(imageName: "xmark.circle.fill", filterName: confusingBerryFilters[0], color: .blue)
                            }
                            
                            FilterOptionView(imageName: "plus", filterName: "Add Berry Filter", color: .secondary)
                                .hidden()
                            
                        }
                        .padding(.horizontal)
                        
                    }
                    
                }
                .padding(.bottom)
            }
            
            .navigationBarTitle(Text(filterResults != 1 ? "\(filterResults) Results" : "\(filterResults) Result"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                plusFilters.removeAll()
                minusFilters.removeAll()
                likesFilters.removeAll()
                dislikesFilters.removeAll()
                confusingBerryFilters.removeAll()
            }) {
                Text("Clear All")
                    .fontWeight(.regular)
            }.disabled(plusFilters.isEmpty && minusFilters.isEmpty && likesFilters.isEmpty && dislikesFilters.isEmpty && confusingBerryFilters.isEmpty), trailing: Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
            })
            
        }
        
    }
}

//struct NatureFilterView_Previews: PreviewProvider {
//    static var previews: some View {
//        NatureFilterView()
//    }
//}
