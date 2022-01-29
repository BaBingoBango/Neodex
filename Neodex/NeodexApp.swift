//
//  NeodexApp.swift
//  Neodex
//
//  Created by Ethan Marshall on 11/25/20.
//

import Foundation
import SwiftUI
import Combine
import OneSignal

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // MARK: - OneSignal Initalization
        
        // Remove this method to stop OneSignal Debugging
        OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE)
        
        // OneSignal initialization
        OneSignal.initWithLaunchOptions(launchOptions)
        OneSignal.setAppId("ebe22e39-d7a4-4d7d-a84e-2ffc5c6330b4")
        
        // promptForPushNotifications will show the native iOS notification permission prompt.
        // We recommend removing the following code and instead using an In-App Message to prompt for notification permission (See step 8)
        OneSignal.promptForPushNotifications(userResponse: { accepted in
          print("User accepted notifications: \(accepted)")
        })
        
        // Set your customer userId
        // OneSignal.setExternalUserId("userId")
        
        return true
    }
}

/// The structure managing intercations with the system: app launching code, the life cycle methods, and the SessionData structure are here.
@main
struct NeodexApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: App Management Variables
    
    /// The system-provided persistance controller variable.
    let persistenceController = PersistenceController.shared
    
    /// The system-provided ScenePhase object  used for app launching.
    @Environment(\.scenePhase) var scenePhase
    
    // Declare a default SessionData variable to be later set up distributed to the views of the app. This runs the App Initializer code seen later in this file.
    var sessionData = SessionData()

    // MARK: App Launching Code
    
    var body: some Scene {
        
        WindowGroup {
            
            // Specify the app's entry point, and pass in the environment objects.
            MainTabView()
                .environmentObject(sessionData)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            
        }
        
        .onChange(of: scenePhase) { phase in
            
            switch phase {
            
            // MARK: Application Life Cycle Code
            
            case .active:
                
                print("The app is active!")
                
            case .background:
                
                print("The app is in the background!")
                
                // Save the tab data
                UserDefaults.standard.set(sessionData.tabs, forKey: "Tabs")
                print("Tab data saved!")
                
            case .inactive:
                
                print("The app is inactive!")
                
                // Save the tab data
                UserDefaults.standard.set(sessionData.tabs, forKey: "Tabs")
                print("Tab data saved!")
            
            default:
                print("Unknown application life cycle value received.")
            
            }
            
        }
        
    }
}

/// This class defines user save data (for example: quick access tabs) that is used during runtime and needs to be shared across many views and presisted for future app launches.
final class SessionData: ObservableObject {
    
    /// The Combine variable for the SessionData class.
    let didChange = PassthroughSubject<SessionData, Never>()
    
    // MARK: Session/Save Data Variables
    
    /// An array of Strings specifying the views selected to populate the app-wide navigation bar.
    @Published var tabs: [String] {
        didSet {
            didChange.send(self)
            
            // Save the tab data
            UserDefaults.standard.set(tabs, forKey: "Tabs")
            print("Tab data saved!")
        }
    }
    
    /// An array of Team objects representing the user's saved Teambuilder teams.
    @Published var teams: [Team] {
        didSet {
            didChange.send(self)

            // Save the team data
            do {
                try UserDefaults.standard.setObject(teams, forKey: "Teams")
            } catch {
                print(error.localizedDescription)
            }
            print("Team data saved!")
        }
    }
    
    /// A UserRecords object representing the user's browsing history.
    @Published var userRecords: UserRecords {
        didSet {
            didChange.send(self)

            // Save the user records data
            do {
                try UserDefaults.standard.setObject(userRecords, forKey: "User Records")
            } catch {
                print(error.localizedDescription)
            }
            print("User records data saved!")
        }
    }
    
    // MARK: App Initializer
    /// The app initializer; this code is run every time the app is launched and the SessionData object for the session is created. It pulls information out of storage and places it inside the SessionData object.
    init() {
        
        // MARK: - 0-1: Read in the pokemon data array from the JSON file and the firstForty array, then place the result in the global pokemonDataList array.
        var jsonData: Data? = nil
        if let filepath = Bundle.main.path(forResource: "PokemonData", ofType: "txt") {
            do {
                jsonData = try String(contentsOfFile: filepath).data(using: .utf8)!
            } catch {
                // contents could not be loaded
            }
        } else {
            // file not found!
        }
        let jsonDecoder = JSONDecoder()
        let pokemonData = try! jsonDecoder.decode([Pokemon].self, from: jsonData!)
        pokemonDataList = Pokemon.firstForty + pokemonData + PokemonForms.listOfPokemonForms
        
        // MARK: 0-2: Read in the move data array from the JSON file, then place the result in the global moveDataList variable.
        var moveJsonData: Data? = nil
        if let filepath = Bundle.main.path(forResource: "Move Data JSON", ofType: "txt") {
            do {
                moveJsonData = try String(contentsOfFile: filepath).data(using: .utf8)!
            } catch {
                // contents could not be loaded
            }
        } else {
            // file not found!
        }
        let moveJsonDecoder = JSONDecoder()
        let moveData = try! moveJsonDecoder.decode([Move].self, from: moveJsonData!)
        moveDataList = moveData + [Move(name: "Burn Up", type: "Fire", category: "Special", description: "To inflict massive damage, the user burns itself out. After using this move, the user will no longer be Fire type.", power: 130, accuracy: 100, PP: 5, maxPP: 8, priority: 0, discID: "", viaLevel: [Method(name: "Arcanine", methodText: "1"), Method(name: "Moltres", methodText: "65"), Method(name: "Ho-Oh", methodText: "99"), Method(name: "Carkol", methodText: "55"), Method(name: "Coalossal", methodText: "63"), Method(name: "Sizzlipede", methodText: "55"), Method(name: "Centiskorch", methodText: "67")], viaTM: [], viaEgg: [], viaTutor: []), Move(name: "Burning Jealousy", type: "Fire", category: "Special", description: "The user attacks with energy from jealousy. This leaves all opposing Pokémon that have had their stats boosted during the turn with a burn.", power: 70, accuracy: 100, PP: 5, maxPP: 8, priority: 0, discID: "", viaLevel: [], viaTM: [], viaEgg: [], viaTutor: [Method(name: "Vulpix", methodText: ""), Method(name: "Ninetales", methodText: ""), Method(name: "Persian-Alola", methodText: ""), Method(name: "Marowak-Alola", methodText: ""), Method(name: "Magmar", methodText: ""), Method(name: "Flareon", methodText: ""), Method(name: "Moltres", methodText: ""), Method(name: "Mew", methodText: ""), Method(name: "Torkoal", methodText: ""), Method(name: "Skuntank", methodText: ""), Method(name: "Spiritomb", methodText: ""), Method(name: "Magmortar", methodText: ""), Method(name: "Heatran", methodText: ""), Method(name: "Liepard", methodText: ""), Method(name: "Darmanitan", methodText: ""), Method(name: "Darmanitan-Galar", methodText: ""), Method(name: "Zorua", methodText: ""), Method(name: "Zoroark", methodText: ""), Method(name: "Litwick", methodText: ""), Method(name: "Lampent", methodText: ""), Method(name: "Chandelure", methodText: ""), Method(name: "Heatmor", methodText: ""), Method(name: "Incineroar", methodText: ""), Method(name: "Turtonator", methodText: ""), Method(name: "Mimikyu", methodText: ""), Method(name: "Thievul", methodText: ""), Method(name: "Impidimp", methodText: ""), Method(name: "Morgrem", methodText: ""), Method(name: "Grimmsnarl", methodText: ""), Method(name: "Cursola", methodText: "")])]
        
        /// There are some form Pokémon that have no moves! Fix this by copying the moves from the standard form:

//        for eachPokemon in pokemonDataList {
//            var standardForm = eachPokemon.name.components(separatedBy: "-")[0]
//            if eachPokemon.name == "Urshifu-Rapid-Strike-Gmax" { standardForm = "Urshifu-Rapid-Strike" }
//            if eachPokemon.name == "Darmanitan-Galar-Zen" { standardForm = "Darmanitan-Galar" }
//            if eachPokemon.name.contains("-") && (filterMoves(name: eachPokemon.name, method: "Level Up").count + filterMoves(name: eachPokemon.name, method: "TM / TR").count + filterMoves(name: eachPokemon.name, method: "Egg Moves").count + filterMoves(name: eachPokemon.name, method: "Move Tutor").count) == 0 {
//                print("Copying moves from \(standardForm) to \(eachPokemon.name)...")
//                
//                /// Find each move that the standard form can learn and add that same move to the list for the alternate form.
//                for i in moveDataList.indices {
//                    
//                    if moveDataList[i].viaLevel.indices.count != 0 {
//                        for j in moveDataList[i].viaLevel.indices {
//                            if moveDataList[i].viaLevel[j].name == standardForm {
//                                moveDataList[i].viaLevel.append(Method(name: eachPokemon.name, methodText: moveDataList[i].viaLevel[j].methodText))
//                            }
//                        }
//                    }
//                    if moveDataList[i].viaTM.indices.count != 0 {
//                        for j in moveDataList[i].viaTM.indices {
//                            if moveDataList[i].viaTM[j].name == standardForm {
//                                moveDataList[i].viaTM.append(Method(name: eachPokemon.name, methodText: moveDataList[i].viaTM[j].methodText))
//                            }
//                        }
//                    }
//                    if moveDataList[i].viaEgg.indices.count != 0 {
//                        for j in moveDataList[i].viaEgg.indices {
//                            if moveDataList[i].viaEgg[j].name == standardForm {
//                                moveDataList[i].viaEgg.append(Method(name: eachPokemon.name, methodText: moveDataList[i].viaEgg[j].methodText))
//                            }
//                        }
//                    }
//                    if moveDataList[i].viaTutor.indices.count != 0 {
//                        for j in moveDataList[i].viaTutor.indices {
//                            if moveDataList[i].viaTutor[j].name == standardForm {
//                                moveDataList[i].viaTutor.append(Method(name: eachPokemon.name, methodText: moveDataList[i].viaTutor[j].methodText))
//                            }
//                        }
//                    }
//                    
//                }
//                
//            }
//        }
//        let newMoveData  = try! JSONEncoder().encode(moveDataList)
//        let jsonString = String(data: newMoveData, encoding: .utf8)!
//        func getDocumentsDirectory() -> URL {
//            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//            print(paths[0])
//            return paths[0]
//        }
//        let filename = getDocumentsDirectory().appendingPathComponent("output.txt")
//
//        do {
//            try jsonString.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
//        } catch {
//            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
//        }
        
        // MARK: - 1: Initalize the tabs array
        if UserDefaults.standard.array(forKey: "Tabs") == nil {
            
            // If no tabs save data is present, assign default data.
            tabs = ["Home", "Pokédex", "Type-O-Matic", "Search"]
            
        } else {
            
            if (UserDefaults.standard.array(forKey: "Tabs") as! [String]).count == 0 {
                
                // If save data is present and empty due to errors, assign default data and print a message.
                tabs = ["Home", "Pokédex", "Type-O-Matic", "Search"]
                print("Tabs restored to default due to data issues!")
                
            } else {
                
                // If save data is present and not empty, assign the saved data.
                tabs = UserDefaults.standard.array(forKey: "Tabs") as! [String]
                
            }
        }
        
        // MARK: - 2: Initalize the teams array
        do {
//            if try UserDefaults.standard.getObject(forKey: "Teams", castTo: [Team].self) == nil {
//                // If no array exists, create a blank array
//                teams = [Team]()
//            } else {
//                // If an array exists (most likely), use it to initalize the session data
//                teams = try UserDefaults.standard.getObject(forKey: "Teams", castTo: [Team].self)
//            }
            teams = try UserDefaults.standard.getObject(forKey: "Teams", castTo: [Team].self)
        } catch {
            // If no array exists, create a blank array
            teams = [Team]()
        }
        
        // MARK: - 3: Initalize the user records
        do {
//            if try UserDefaults.standard.getObject(forKey: "User Records", castTo: UserRecords.self) == nil {
//                // If no object exists, create a blank object
//                userRecords = UserRecords()
//            } else {
//                // If an object exists (most likely), use it to initalize the session data
//                userRecords = try UserDefaults.standard.getObject(forKey: "User Records", castTo: UserRecords.self)
//            }
            userRecords = try UserDefaults.standard.getObject(forKey: "User Records", castTo: UserRecords.self)
        } catch {
            // If no object exists, create a blank object
            userRecords = UserRecords()
        }
        
        // MARK: - 4: Index content for Spotlight
        if !userRecords.firstTimeIndex {
            if !userRecords.hasIndexedPokemon {
                DispatchQueue.main.async {
                    SpotlightServices.indexPokemon()
                }
                userRecords.hasIndexedPokemon = true
            }
            if !userRecords.hasIndexedMoves {
                DispatchQueue.main.async {
                    SpotlightServices.indexMoves()
                }
                userRecords.hasIndexedMoves = true
            }
            if !userRecords.hasIndexedAbilities {
                DispatchQueue.main.async {
                    SpotlightServices.indexAbilities()
                }
                userRecords.hasIndexedAbilities = true
            }
            if !userRecords.hasIndexedNatures {
                DispatchQueue.main.async {
                    SpotlightServices.indexNatures()
                }
                userRecords.hasIndexedNatures = true
            }
            if !userRecords.hasIndexedItems {
                DispatchQueue.main.async {
                    SpotlightServices.indexItems()
                }
                userRecords.hasIndexedItems = true
            }
        }
        if !userRecords.firstTimeIndex {
            userRecords.firstTimeIndex = true
        }
        
    }
    
}
