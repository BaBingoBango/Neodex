//
//  GlobalStatsItemsDetail.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/7/21.
//

import SwiftUI

struct GlobalStatsItemsDetail: View {
    
    // Variables
    var sortedItems: [String]
    var detail: RankingDetail
    @State var showingMoreItems = false
    var name: String
    
    var body: some View {
        
        HStack {
            Text("Top Items")
                .font(.title)
                .fontWeight(.bold)
            if sortedItems.count >= 4 {
                Button(action: {
                    self.showingMoreItems.toggle()
                }) {
                    HStack {
                        Text("See All")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.blue)
                            .padding(.leading, 5)
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.blue)
                    }
                }
                .sheet(isPresented: $showingMoreItems) {
                    MoreItemsView(sortedItems: sortedItems, items: detail.items, name: name)
                }
            }
            Spacer()
        }
        .padding([.top, .leading])
        
        if !sortedItems.isEmpty && sortedItems.count >= 4 {

            ForEach(sortedItems[0...2], id: \.self) { itemName in

                ItemRankOption(rank: sortedItems.firstIndex(of: itemName)! + 1, name: itemName, usage: detail.items[itemName]!.rounded(toPlaces: 1))

            }

        } else if !sortedItems.isEmpty {
            ForEach(sortedItems, id: \.self) { itemName in

                ItemRankOption(rank: sortedItems.firstIndex(of: itemName)! + 1, name: itemName, usage: detail.items[itemName]!.rounded(toPlaces: 1))

            }
        }
        
    }
}

//struct GlobalStatsItemsDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        GlobalStatsItemsDetail()
//    }
//}
