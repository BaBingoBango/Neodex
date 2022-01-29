//
//  DatabaseScraper.swift
//  Neodex
//
//  Created by Ethan Marshall on 3/2/21.
//

import Foundation

/// Scapes the Pokémon Database website for the data on a certain Pokémon using the raw HTML code.
/// - Parameter HTML: The raw HTML code for the Pokémon from the PDB website.
/// - Returns: A Pokémon object containing the data retrieved. If data could not be retrieved, the value returned is nil.
func scrapePokemonHTML(HTML: String) -> Pokemon? {
    
    // MARK: 1 AND 2: Prepare HTML code
    let webpage = HTML
    
    // MARK: 3: Parse the webpage string for Pokémon data
    
    // MARK: 3-1: Name
    let pokemonName = webpage.components(separatedBy: " Pokédex: stats, moves, evolution")[0].components(separatedBy: """
            <head>
            <meta charset="utf-8">
            <title>
            """)[1]
    
    // MARK: 3-2: Dex Number
    let pokemonDexNum = webpage.components(separatedBy: """
            <th>National &#8470;</th>
            <td><strong>
            """)[1].components(separatedBy: "</strong></td>")[0]
    
    // MARK: 3-3: Types
    var pokemonType1 = "TYPE1"
    var pokemonType2 = "TYPE2"
    if !(webpage.components(separatedBy: "is a <a href=").count >= 2) {
        // The page is using "an"
        pokemonType1 = webpage.components(separatedBy: "is an <a href=")[1].components(separatedBy: "\">")[1].components(separatedBy: "</a>")[0]
        pokemonType2 = webpage.components(separatedBy: "is an <a href=")[1].components(separatedBy: "\">")[2].components(separatedBy: "</a>")[0]
    } else {
        // The page is using "a"
        pokemonType1 = webpage.components(separatedBy: "is a <a href=")[1].components(separatedBy: "\">")[1].components(separatedBy: "</a>")[0]
        pokemonType2 = webpage.components(separatedBy: "is a <a href=")[1].components(separatedBy: "\">")[2].components(separatedBy: "</a>")[0]
    }
    if pokemonType2.count >= 10 {
        pokemonType2 = ""
    }
    
    // MARK: 3-4: Height
    let pokemonHeight = webpage.components(separatedBy: """
<th>Height</th>
<td>
""")[1].components(separatedBy: "&nbsp;m")[0]
    
    // MARK: 3-5: Weight
    let pokemonWeight = webpage.components(separatedBy: """
<th>Weight</th>
<td>
""")[1].components(separatedBy: "&nbsp;kg")[0]
    
    // MARK: 3-6: Species Name
    let pokemonSpecies = webpage.components(separatedBy: """
<th>Species</th>
<td>
""")[1].components(separatedBy: " Pokémon</td>")[0]
    
    // MARK: 3-7: Abilities
    var pokemonAbility1 = "ABILITY1"
    var pokemonAbility2 = ""
    var pokemonHiddenAbility = ""
    let abilities = webpage.components(separatedBy: """
<th>Abilities</th>
<td><span class="text-muted">1.
""")[1].components(separatedBy: "<th>Local")[0].components(separatedBy: "title=")
    for i in 1...4 {
        if abilities.count >= i {
            if i == 1 && !abilities[i].contains("hidden") {
                pokemonAbility1 = abilities[i].components(separatedBy: "\">")[1].components(separatedBy: "</a>")[0]
            } else if i == 2 && abilities.count >= 3 && !abilities[i].contains("hidden") {
                pokemonAbility2 = abilities[i].components(separatedBy: "\">")[1].components(separatedBy: "</a>")[0]
            } else {
                if abilities[i - 1].contains("hidden") {
                    pokemonHiddenAbility = abilities[i - 1].components(separatedBy: "\">")[1].components(separatedBy: "</a>")[0]
                }
            }
        }
    }
    
    // MARK: 3-8: EV Yield
    let rawEV = webpage.components(separatedBy: """
<th>EV yield</th>
<td class="text">\n
""")[1].components(separatedBy: "</td>")[0].trimmingCharacters(in: .whitespaces).components(separatedBy: ",")
    var pokemonEVYield = ""
    for eachEV in rawEV {
        // Split apart the number part and the word part
        let number = eachEV.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)[0]
        var word = eachEV.components(separatedBy: .decimalDigits)[1].trimmingCharacters(in: .whitespaces)
        switch word {
        case "HP": word = "HP"
        case "Attack": word = "Attack"
        case "Special Attack": word = "Sp. Atk"
        case "Defense": word = "Defense"
        case "Special Defense": word = "Sp. Def"
        case "Speed": word = "Speed"
        default: word = ""
        }
        pokemonEVYield += "\(number) \(word), "
    }
    pokemonEVYield = String(pokemonEVYield[pokemonEVYield.startIndex...pokemonEVYield.index(pokemonEVYield.endIndex, offsetBy: -3)])
    
    // MARK: 3-9: Catch Rate
    let pokemonCatchRate = webpage.components(separatedBy: """
<th>Catch rate</th>
<td>

""")[1].components(separatedBy: " <small class")[0]
    
    // MARK: 3-10: Base Friendship
    let pokemonBaseFriendship = webpage.components(separatedBy: """
<th>Base <a href="/glossary#def-friendship">Friendship</a></th>
<td>

""")[1].components(separatedBy: " <small class")[0]
    
    // MARK: 3-11: Base EXP
    let pokemonBaseEXP = webpage.components(separatedBy: """
<th>Base Exp.</th>
<td>
""")[1].components(separatedBy: "</td>")[0]
    
    // MARK: 3-12: Growth Rate
    let pokemonGrowthRate = webpage.components(separatedBy: """
<th>Growth Rate</th>
<td>
""")[1].components(separatedBy: "</td>")[0]
    
    // MARK: 3-13: Egg Groups
    let rawEggGroups = webpage.components(separatedBy: """
<th>Egg Groups</th>
<td>
""")[1].components(separatedBy: "</tr>")[0].components(separatedBy: ",")
    var pokemonEggGroups: [String] = []
    for eachEggLine in rawEggGroups {
        if eachEggLine.contains("/egg-group/") {
            pokemonEggGroups.append(eachEggLine.components(separatedBy: "\">")[1].components(separatedBy: "</a>")[0])
        }
    }
    
    // MARK: 3-14: Male Rate
    var pokemonMaleRate = webpage.components(separatedBy: """
<th>Gender</th>
""")[1].components(separatedBy: "Egg cycles")[0]
    if pokemonMaleRate.contains("Genderless") {
        pokemonMaleRate = "-1.0"
    } else {
        pokemonMaleRate = webpage.components(separatedBy: """
    <th>Gender</th>
    <td><span class="text-blue">
    """)[1].components(separatedBy: "% male</span>")[0]
    }
    
    // MARK: 3-15: Egg Cycles
    var pokemonEggCycles = ""
    if webpage.contains("""
<th><a href="/glossary#def-eggcycle">Egg cycles</a></th>
<td>
""") {
        pokemonEggCycles = webpage.components(separatedBy: """
    <th><a href="/glossary#def-eggcycle">Egg cycles</a></th>
    <td>
    """)[1].components(separatedBy: " <small class")[0]
    } else {
        pokemonEggCycles = webpage.components(separatedBy: """
    <th><a href="/glossary#def-eggcycle">Egg cycles</a></th>
     <td>
    """)[1].components(separatedBy: " <small class")[0]
    }
    
    // MARK: 3-16: Base Stats
    var pokemonHP = ""
    if webpage.contains("""
<th>HP</th>
<td class="cell-num">
""") {
        pokemonHP = webpage.components(separatedBy: """
    <th>HP</th>
    <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    } else {
        pokemonHP = webpage.components(separatedBy: """
    <th>HP</th>
     <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    }
    
    let pokemonAttack = webpage.components(separatedBy: """
<th>Attack</th>
<td class="cell-num">
""")[1].components(separatedBy: "</td>")[0]
    
    var pokemonDefense = ""
    if webpage.contains("""
<th>Defense</th>
<td class="cell-num">
""") {
        pokemonDefense = webpage.components(separatedBy: """
    <th>Defense</th>
    <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    } else {
        pokemonDefense = webpage.components(separatedBy: """
    <th>Defense</th>
     <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    }
    
    var pokemonSpAtk = ""
    if webpage.contains("""
<th>Sp. Atk</th>
<td class="cell-num">
""") {
        pokemonSpAtk = webpage.components(separatedBy: """
    <th>Sp. Atk</th>
    <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    } else {
        pokemonSpAtk = webpage.components(separatedBy: """
    <th>Sp. Atk</th>
     <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    }
    
    var pokemonSpDef = ""
    if webpage.contains("""
<th>Sp. Def</th>
<td class="cell-num">
""") {
        pokemonSpDef = webpage.components(separatedBy: """
    <th>Sp. Def</th>
    <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    } else {
        pokemonSpDef = webpage.components(separatedBy: """
    <th>Sp. Def</th>
     <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    }
    
    var pokemonSpeed = ""
    if webpage.contains("""
<th>Speed</th>
<td class="cell-num">
""") {
        pokemonSpeed = webpage.components(separatedBy: """
    <th>Speed</th>
    <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    } else {
        pokemonSpeed = webpage.components(separatedBy: """
    <th>Speed</th>
     <td class="cell-num">
    """)[1].components(separatedBy: "</td>")[0]
    }
    
    // MARK: 3-17: Evolutions
    let evolutionsSection = webpage.components(separatedBy: """
<h2>Evolution chart</h2>

""")[1].components(separatedBy: """
</div>
<h2>
""")[0]
    let splitEvoSection = evolutionsSection.components(separatedBy: "</a><br>")
    var pokemonEvolutions: [Evolution] = []
    if splitEvoSection.count >= 2 {
        for index in 0...(splitEvoSection.count - 2) {
            // Get the name
            let evoName = splitEvoSection[index].components(separatedBy: "\">").last!
            var evoLevel = -1
            var evoTreeLevel = -1
            var evoMethod = "BADMETHOD"
            if !splitEvoSection[index].contains("infocard infocard-arrow") {
                // Fill out the object if the tree level is 1
                evoLevel = 1
                evoTreeLevel = 1
                evoMethod = ""
            } else {
                // Fill out the object if the tree level is not 1
                if splitEvoSection[index].contains("Level") {
                    // Get the numerical level number
                    let evoString = splitEvoSection[index].components(separatedBy: "(Level ")[1].components(separatedBy: ")")[0]
                    if evoString.contains(",") {
                        evoLevel = Int(evoString.components(separatedBy: ",")[0])!
                    } else {
                        evoLevel = Int(evoString)!
                    }
                    evoMethod = "Level Up"
                } else {
                    // Get the alternative method name
                    evoLevel = 1
                    var scannedMethod = splitEvoSection[index].components(separatedBy: "<small>(")[1].components(separatedBy: ")</small")[0]
                    if scannedMethod.contains("\">") {
                        let obscuredText = scannedMethod.components(separatedBy: "\">")[1].components(separatedBy: "</a>")[0]
                        scannedMethod = obscuredText
                    }
                    evoMethod = scannedMethod
                }
                // Fill in the tree level
                evoTreeLevel = index + 1
                if splitEvoSection[index].contains("icon-arrow-ne") {
                    evoTreeLevel = index + 1
                } else if splitEvoSection[index].contains("icon-arrow-se") {
                    evoTreeLevel = pokemonEvolutions.last!.treeLevel
                }
                for j in 0...(pokemonEvolutions.count - 1) {
                    if evoName == pokemonEvolutions[j].pokemon && (pokemonEvolutions[j].pokemon != pokemonEvolutions[0].pokemon) {
                        evoTreeLevel = pokemonEvolutions[j].treeLevel
                    }
                    if evoLevel == pokemonEvolutions[j].level && j != 0 && (pokemonEvolutions[j].pokemon != pokemonEvolutions[0].pokemon) {
                        evoTreeLevel = pokemonEvolutions[j].treeLevel
                    }
                }
//                if pokemonEvolutions.count >= 2 {
//                    evoTreeLevel = index + 1
//                    for j in 1...(pokemonEvolutions.count - 1) {
//                        if pokemonEvolutions[j].level == evoLevel {
//                            evoTreeLevel = pokemonEvolutions[j].treeLevel
//                        }
//                    }
//                } else {
//                    evoTreeLevel = index + 1
//                }
            }
            pokemonEvolutions.append(Evolution(level: evoLevel, pokemon: evoName, method: evoMethod, treeLevel: evoTreeLevel))
        }
    }
    
    // MARK: 3-18: Dex Entries
    var pokemonDexEntries: [DexEntry] = []
    // Sword
    if webpage.contains("Sword</span></th> <td class=\"cell-med-text\">") {
        let swordEntry = webpage.components(separatedBy: "Sword</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Sword", entry: swordEntry))
    }
    // Shield
    if webpage.contains("Shield</span></th> <td class=\"cell-med-text\">") {
        let shieldEntry = webpage.components(separatedBy: "Shield</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Shield", entry: shieldEntry))
    }
    // LGP/LGE
    if webpage.contains("<th><span class=\"igame lets-go-pikachu\">Let's Go Pikachu</span><br><span class=\"igame lets-go-eevee\">Let's Go Eevee</span></th> <td class=\"cell-med-text\">") {
        let LGPEentry = webpage.components(separatedBy: "<th><span class=\"igame lets-go-pikachu\">Let's Go Pikachu</span><br><span class=\"igame lets-go-eevee\">Let's Go Eevee</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Let's Go", entry: LGPEentry))
    }
    // Ultra Sun
    if webpage.contains("Ultra Sun</span></th> <td class=\"cell-med-text\">") {
        let ultraSunEntry = webpage.components(separatedBy: "Ultra Sun</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Ultra Sun", entry: ultraSunEntry))
    }
    // Ultra Moon
    if webpage.contains("Ultra Moon</span></th> <td class=\"cell-med-text\">") {
        let ultraMoonEntry = webpage.components(separatedBy: "Ultra Moon</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Ultra Moon", entry: ultraMoonEntry))
    }
    // Sun
    if webpage.contains("Sun</span></th> <td class=\"cell-med-text\">") {
        let sunEntry = webpage.components(separatedBy: "Sun</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Sun", entry: sunEntry))
    }
    // Moon
    if webpage.contains("Moon</span></th> <td class=\"cell-med-text\">") {
        let moonEntry = webpage.components(separatedBy: "Moon</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Moon", entry: moonEntry))
    }
    // OR / AS
    if webpage.contains("<th><span class=\"igame omega-ruby\">Omega Ruby</span><br><span class=\"igame alpha-sapphire\">Alpha Sapphire</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "<th><span class=\"igame omega-ruby\">Omega Ruby</span><br><span class=\"igame alpha-sapphire\">Alpha Sapphire</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Omega Ruby / Alpha Sapphire", entry: entry))
    } else {
        // X / OR
        if webpage.contains("<th><span class=\"igame x\">X</span><br><span class=\"igame omega-ruby\">Omega Ruby</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "<th><span class=\"igame x\">X</span><br><span class=\"igame omega-ruby\">Omega Ruby</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon X / Omega Ruby", entry: entry))
        } else {
            // OR
            if webpage.contains("Omega Ruby</span></th> <td class=\"cell-med-text\">") {
                let entry = webpage.components(separatedBy: "Omega Ruby</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
                pokemonDexEntries.append(DexEntry(source: "Pokémon Omega Ruby", entry: entry))
            }
        }
        // Y / AS
        if webpage.contains("<th><span class=\"igame y\">Y</span><br><span class=\"igame alpha-sapphire\">Alpha Sapphire</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "<th><span class=\"igame y\">Y</span><br><span class=\"igame alpha-sapphire\">Alpha Sapphire</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon Y / Alpha Sapphire", entry: entry))
        } else {
            // AS
            if webpage.contains("Alpha Sapphire</span></th> <td class=\"cell-med-text\">") {
                let entry = webpage.components(separatedBy: "Alpha Sapphire</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
                pokemonDexEntries.append(DexEntry(source: "Pokémon Alpha Sapphire", entry: entry))
            }
        }
    }
    // X
    if webpage.contains("X</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "X</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon X", entry: entry))
    }
    // Y
    if webpage.contains("Y</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Y</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Y", entry: entry))
    }
    // Black / White, Black 2 / White 2
    if webpage.contains("<th><span class=\"igame black\">Black</span><br><span class=\"igame white\">White</span><br><span class=\"igame black-2\">Black 2</span><br><span class=\"igame white-2\">White 2</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "<th><span class=\"igame black\">Black</span><br><span class=\"igame white\">White</span><br><span class=\"igame black-2\">Black 2</span><br><span class=\"igame white-2\">White 2</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Black / White 1 & 2", entry: entry))
    } else {
        // Black 2 / White 2
        if webpage.contains("<th><span class=\"igame black-2\">Black 2</span><br><span class=\"igame white-2\">White 2</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "<th><span class=\"igame black-2\">Black 2</span><br><span class=\"igame white-2\">White 2</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon Black 2 / White 2", entry: entry))
        } else {
            // Black 2
            if webpage.contains("Black 2</span></th> <td class=\"cell-med-text\">") {
                let entry = webpage.components(separatedBy: "Black 2</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
                pokemonDexEntries.append(DexEntry(source: "Pokémon Black 2", entry: entry))
            }
            // White 2
            if webpage.contains("White 2</span></th> <td class=\"cell-med-text\">") {
                let entry = webpage.components(separatedBy: "White 2</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
                pokemonDexEntries.append(DexEntry(source: "Pokémon White 2", entry: entry))
            }
        }
        // Black / White
        if webpage.contains("<th><span class=\"igame black\">Black</span><br><span class=\"igame white\">White</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "<th><span class=\"igame black\">Black</span><br><span class=\"igame white\">White</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon Black / White", entry: entry))
        } else {
            // Black
            if webpage.contains("Black</span></th> <td class=\"cell-med-text\">") {
                let entry = webpage.components(separatedBy: "Black</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
                pokemonDexEntries.append(DexEntry(source: "Pokémon Black", entry: entry))
            }
            // White
            if webpage.contains("White</span></th> <td class=\"cell-med-text\">") {
                let entry = webpage.components(separatedBy: "White</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
                pokemonDexEntries.append(DexEntry(source: "Pokémon White", entry: entry))
            }
        }
    }
    // HeartGold / SoulSilver
    if webpage.contains("<th><span class=\"igame heartgold\">HeartGold</span><br><span class=\"igame soulsilver\">SoulSilver</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "<th><span class=\"igame heartgold\">HeartGold</span><br><span class=\"igame soulsilver\">SoulSilver</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon HeartGold / SoulSilver", entry: entry))
    } else {
        // HeartGold
        if webpage.contains("HeartGold</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "HeartGold</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon HeartGold", entry: entry))
        }
        // SoulSilver
        if webpage.contains("SoulSilver</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "SoulSilver</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon SoulSilver", entry: entry))
        }
    }
    // Diamond / Pearl
    if webpage.contains("<th><span class=\"igame diamond\">Diamond</span><br><span class=\"igame pearl\">Pearl</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "<th><span class=\"igame diamond\">Diamond</span><br><span class=\"igame pearl\">Pearl</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Diamond / Pearl", entry: entry))
    }
    // Diamond
    if webpage.contains("Diamond</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Diamond</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Diamond", entry: entry))
    }
    // Pearl
    if webpage.contains("Pearl</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Pearl</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Pearl", entry: entry))
    }
    // Platinum
    if webpage.contains("Platinum</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Platinum</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Platinum", entry: entry))
    }
    // DPP
    if webpage.contains("<th><span class=\"igame diamond\">Diamond</span><br><span class=\"igame pearl\">Pearl</span><br><span class=\"igame platinum\">Platinum</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "<th><span class=\"igame diamond\">Diamond</span><br><span class=\"igame pearl\">Pearl</span><br><span class=\"igame platinum\">Platinum</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Diamond / Pearl / Platinum", entry: entry))
    }
    // FireRed / LeafGreen
    if webpage.contains("<th><span class=\"igame firered\">FireRed</span><br><span class=\"igame leafgreen\">LeafGreen</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "<th><span class=\"igame firered\">FireRed</span><br><span class=\"igame leafgreen\">LeafGreen</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon FireRed / LeafGreen", entry: entry))
    } else {
        // FireRed
        if webpage.contains("FireRed</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "FireRed</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon FireRed", entry: entry))
        }
        // LeafGreen
        if webpage.contains("LeafGreen</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "LeafGreen</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon LeafGreen", entry: entry))
        }
    }
    // Emerald
    if webpage.contains("Emerald</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Emerald</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Emerald", entry: entry))
    }
    // Ruby and Sapphire
    if webpage.contains("<th><span class=\"igame ruby\">Ruby</span><br><span class=\"igame sapphire\">Sapphire</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "<th><span class=\"igame ruby\">Ruby</span><br><span class=\"igame sapphire\">Sapphire</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Ruby / Sapphire", entry: entry))
    } else {
        // Ruby
        if webpage.contains("Ruby</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "Ruby</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon Ruby", entry: entry))
        }
        // Sapphire
        if webpage.contains("Sapphire</span></th> <td class=\"cell-med-text\">") {
            let entry = webpage.components(separatedBy: "Sapphire</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
            pokemonDexEntries.append(DexEntry(source: "Pokémon Sapphire", entry: entry))
        }
    }
    // Gold
    if webpage.contains("Gold</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Gold</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Gold", entry: entry))
    }
    // Silver
    if webpage.contains("Silver</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Silver</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Silver", entry: entry))
    }
    // Crystal
    if webpage.contains("Crystal</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Crystal</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Crystal", entry: entry))
    }
    // Yellow
    if webpage.contains("Yellow</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "Yellow</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Yellow", entry: entry))
    }
    // Red / Blue
    if webpage.contains("<th><span class=\"igame red\">Red</span><br><span class=\"igame blue\">Blue</span></th> <td class=\"cell-med-text\">") {
        let entry = webpage.components(separatedBy: "<th><span class=\"igame red\">Red</span><br><span class=\"igame blue\">Blue</span></th> <td class=\"cell-med-text\">")[1].components(separatedBy: "</td>")[0]
        pokemonDexEntries.append(DexEntry(source: "Pokémon Red / Blue", entry: entry))
    }
    
    // MARK: 3-19: Locations
    var pokemonLocations: [String] = []
    let locationsSection = webpage.components(separatedBy: "<h2>Where to find")[1].components(separatedBy: "</tbody>")[0]
    // Sword and Shield
    if locationsSection.contains("""
<th><span class="igame sword">Sword</span><br><span class="igame shield">Shield</span></th>
<td>
""") {
        let locationsText = webpage.components(separatedBy: "<h2>Where to find")[1].components(separatedBy: """
    <th><span class="igame sword">Sword</span><br><span class="igame shield">Shield</span></th>
    <td>
    """)[1].components(separatedBy: "</td>")[0]
        let locations = locationsText.components(separatedBy: "\">")
        if !locationsText.contains("Evolve") {
            if locations.count >= 2 {
                for i in 1...(locations.count - 1) {
                    let location = locations[i].components(separatedBy: "</a>")[0]
                    pokemonLocations.append(location)
                }
            }
        }
    } else {
        let swordLocationsText = webpage.components(separatedBy: "<h2>Where to find")[1].components(separatedBy: "<th><span class=\"igame sword\">Sword</span>")[1].components(separatedBy: "</td>")[0]
        let swordLocations = swordLocationsText.components(separatedBy: "\">")
        if !swordLocationsText.contains("Evolve") {
            if swordLocations.count >= 2 {
                for i in 1...(swordLocations.count - 1) {
                    let location = swordLocations[i].components(separatedBy: "</a>")[0]
                    pokemonLocations.append("SWORD: \(location)")
                }
            }
        }
        
        var shieldLocationsText = ""
        if webpage.components(separatedBy: "<h2>Where to find")[1].contains("<br><span class=\"igame shield\">Shield</span>") {
            shieldLocationsText = webpage.components(separatedBy: "<h2>Where to find")[1].components(separatedBy: "<br><span class=\"igame shield\">Shield</span>")[1].components(separatedBy: "</td>")[0]
        } else {
            shieldLocationsText = webpage.components(separatedBy: "<h2>Where to find")[1].components(separatedBy: "<th><span class=\"igame shield\">Shield</span>")[1].components(separatedBy: "</td>")[0]
        }
        let shieldLocations = shieldLocationsText.components(separatedBy: "\">")
        if !shieldLocationsText.contains("Evolve") {
            if shieldLocations.count >= 2 {
                for i in 1...(shieldLocations.count - 1) {
                    let location = shieldLocations[i].components(separatedBy: "</a>")[0]
                    if !pokemonLocations.contains("SWORD: \(location)") {
                        pokemonLocations.append("SHIELD: \(location)")
                    } else {
                        pokemonLocations[pokemonLocations.firstIndex(of: ("SWORD: \(location)"))!] = location
                    }
                }
            }
        }
    }
    
    // MARK: 4: Create, print, and return a Pokemon object
    let answer = Pokemon(name: pokemonName, nationalDexNum: pokemonDexNum, type1: pokemonType1, type2: pokemonType2, speciesName: pokemonSpecies, height: Double(pokemonHeight)!, weight: Double(pokemonWeight)!, ability1: pokemonAbility1, ability2: pokemonAbility2, hiddenAbility: pokemonHiddenAbility, EVYield: pokemonEVYield, catchRate: Int(pokemonCatchRate)!, baseFriendship: Int(pokemonBaseFriendship)!, baseEXP: Int(pokemonBaseEXP)!, growthRate: pokemonGrowthRate, eggGroups: pokemonEggGroups, maleRate: Double(pokemonMaleRate)!, eggCycles: Int(pokemonEggCycles.trimmingCharacters(in: .whitespaces))!, baseStats: [Int(pokemonHP)!, Int(pokemonAttack)!, Int(pokemonDefense)!, Int(pokemonSpAtk)!, Int(pokemonSpDef)!, Int(pokemonSpeed)!], evolutions: pokemonEvolutions, dexEntries: pokemonDexEntries, locations: pokemonLocations)
    
//    print("Pokemon(name: \"\(pokemonName)\", nationalDexNum: \"\(pokemonDexNum)\", type1: \"\(pokemonType1)\", type2: \"\(pokemonType2)\", speciesName: \"\(pokemonSpecies)\", height: \(Double(pokemonHeight)!), weight: \(Double(pokemonWeight)!), ability1: \"\(pokemonAbility1)\", ability2: \"\(pokemonAbility2)\", hiddenAbility: \"\(pokemonHiddenAbility)\", EVYield: \"\(pokemonEVYield)\", catchRate: \(Int(pokemonCatchRate)!), baseFriendship: \(Int(pokemonBaseFriendship)!), baseEXP: \(Int(pokemonBaseEXP)!), growthRate: \"\(pokemonGrowthRate)\", eggGroups: \(pokemonEggGroups), maleRate: \(Double(pokemonMaleRate)!), eggCycles: \(Int(pokemonEggCycles.trimmingCharacters(in: .whitespaces))!), baseStats: [\(Int(pokemonHP)!), \(Int(pokemonAttack)!), \(Int(pokemonDefense)!), \(Int(pokemonSpAtk)!), \(Int(pokemonSpDef)!), \(Int(pokemonSpeed)!)], evolutions: \(pokemonEvolutions), dexEntries: \(pokemonDexEntries), locations: \(pokemonLocations)),\n")
    
    return answer
    
}
