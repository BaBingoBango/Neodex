//
//  NeodexTests.swift
//  NeodexTests
//
//  Created by Ethan Marshall on 11/25/20.
//

import XCTest
@testable import Neodex

class NeodexTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testForZeroMoves() throws {
        func filterMoves(name: String, method: String) -> [Move] {
            var answer: [Move] = []
            for eachMove in moveDataList {
                
                if method == "Level Up" {
                    for eachPokemon in eachMove.viaLevel {
                        if name == eachPokemon.name {
                            answer.append(eachMove)
                        }
                    }
                    
                } else if method == "TM / TR" {
                    for eachPokemon in eachMove.viaTM {
                        if name == eachPokemon.name {
                            answer.append(eachMove)
                        }
                    }
                    
                } else if method == "Egg Moves" {
                    
                    for eachPokemon in eachMove.viaEgg {
                        if name == eachPokemon.name {
                            answer.append(eachMove)
                        }
                    }
                    
                } else if method == "Move Tutor" {
                    
                    for eachPokemon in eachMove.viaTutor {
                        if name == eachPokemon.name {
                            answer.append(eachMove)
                        }
                    }
                    
                }
            }
            return answer
        }
        
        var testArray: [Bool] = []
        
        for eachPokemon in pokemonDataList {
            if (filterMoves(name: eachPokemon.name, method: "Level Up").count + filterMoves(name: eachPokemon.name, method: "TM / TR").count + filterMoves(name: eachPokemon.name, method: "Egg Moves").count + filterMoves(name: eachPokemon.name, method: "Move Tutor").count) != 0 {
                testArray.append(true)
            } else {
                testArray.append(false)
                XCTFail("\(eachPokemon.name) has no moves!")
            }
        }
        
        var correctArray: [Bool] = []
        for _ in pokemonDataList {
            correctArray.append(true)
        }
        
        XCTAssertEqual(testArray, correctArray)
        
    }
    
    func testTeamMemberExport() throws {
        
        var testTeamMember = TeamMember(pokemon: Neodex.pokemonDataList[0])
        
        testTeamMember.gender = "Female"
        testTeamMember.isShiny = true
        testTeamMember.item = "Absorb Bulb"
        testTeamMember.level = 99
        testTeamMember.EVs = [0, 100, 20, 30, 5, 0]
        testTeamMember.IVs = [25, 0, 31, 0, 5, 31]
        testTeamMember.moves = [Move.moveLookup(name: "Vine Whip"), nil, Move.moveLookup(name: "Magical Leaf"), nil]
        
        let output = testTeamMember.export()
        XCTAssertEqual(output, """
                                Bulbasaur (F) @ Absorb Bulb
                                Ability: Overgrow
                                Level: 99
                                Shiny: Yes
                                EVs: 100 Atk / 20 Def / 30 SpA / 5 SpD
                                Serious Nature
                                IVs: 25 HP / 0 Atk / 0 SpA / 5 SpD
                                - Vine Whip
                                - Magical Leaf
                                """)
        
    }
    
    func testTeamMemberImport1() throws {
        
        let input = """
                    Ratty (Raticate) (M) @ Choice Band
                    Ability: Hustle
                    Level: 99
                    Shiny: Yes
                    EVs: 60 HP / 64 Atk / 8 Def / 68 SpA / 24 Spe
                    Impish Nature
                    IVs: 29 HP / 30 SpA / 30 Spe
                    - Vine Whip
                    - Magical Leaf
                    """
        let teamMember = TeamMember.importMember(input: input)
        
        XCTAssertEqual(teamMember.export(), input)
        
    }
    
    func testTeamMemberImport2() throws {
        
        let input = """
                    Sandslash (M)
                    Ability: Sand Veil
                    Level: 100
                    Hardy Nature
                    """
        let teamMember = TeamMember.importMember(input: input)
        
        XCTAssertEqual(teamMember.export(), input)
        
    }
    
    func testTeamMemberImport3() throws {
        
        let input = """
                    Plabty (Bulbasaur) (F) @ abilitycapsule
                    Ability: Chlorophyll
                    Level: 50
                    Shiny: Yes
                    EVs: 10 HP / 11 Atk / 13 Def / 20 SpA / 100 SpD / 252 Spe
                    Hardy Nature
                    IVs: 10 HP / 11 Atk / 13 Def / 20 SpA / 30 SpD / 30 Spe
                    - Magical Leaf
                    - Vine Whip
                    """
        let teamMember = TeamMember.importMember(input: input)
        
        XCTAssertEqual(teamMember.export(), input)
        
    }
    
    func testTooManyEVsAndIVsImport() throws {
        
        let input = """
                    Plabty (Bulbasaur) (F) @ abilitycapsule
                    Ability: Chlorophyll
                    Level: 50
                    Shiny: Yes
                    EVs: 999 HP / 11 Atk / 13 Def / 253 SpA / 999 SpD / 2000 Spe
                    Hardy Nature
                    IVs: 32 HP / 11 Atk / 80 Def / 20 SpA / 30 SpD / 30 Spe
                    - Magical Leaf
                    - Vine Whip
                    """
        _ = TeamMember.importMember(input: input)
        
        XCTAssertEqual(0, 0)
        
    }
    
    func testTeamImport() throws {
        
        let input = """
                    Plabty (Bulbasaur) (F) @ abilitycapsule
                    Ability: Chlorophyll
                    Level: 50
                    Shiny: Yes
                    EVs: 10 HP / 11 Atk / 13 Def / 20 SpA / 100 SpD / 252 Spe
                    Hardy Nature
                    IVs: 10 HP / 11 Atk / 13 Def / 20 SpA / 30 SpD / 30 Spe
                    - Magical Leaf
                    - Vine Whip

                    WTF (Squirtle) (M) @ Big Root
                    Ability: Rain Dish
                    Level: 50
                    Jolly Nature
                    - Vine Whip

                    Sandslash (M)
                    Ability: Sand Veil
                    Level: 50
                    Serious Nature
                    """
        let team = Team.importTeam(input: input)
        
        XCTAssertEqual(team.export(), "\(input)\n\n")
    }
    
}
