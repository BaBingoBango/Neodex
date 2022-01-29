//
//  Item.swift
//  Neodex
//
//  Created by Ethan Marshall on 1/3/21.
//

import Foundation

struct Item: Codable {
    
    // MARK: - Variables
    var name: String
    var desc: String
    var evoEffects: [String]
    var category: ItemType
    var moveName: [String]?
    
    static let itemList: [Item] = [
    
        Item(name: "Ability Capsule", desc: "A capsule that allows a Pokémon with two Abilities to switch between these Abilities when it is used.", evoEffects: [], category: .enhancer),
        
        Item(name: "Ability Patch", desc: "A patch that allows a Pokémon with a regular Ability to have its Hidden Ability.", evoEffects: [], category: .enhancer),
        
        Item(name: "Ability Urge", desc: "When used, it activates the Ability of an ally Pokémon.", evoEffects: [], category: .battle),
        
        Item(name: "Abomasite", desc: "One of a variety of mysterious Mega Stones. Have Abomasnow hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Absolite", desc: "One of a variety of mysterious Mega Stones. Have Absol hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Absorb Bulb", desc: "An item to be held by a Pokémon. It boosts Sp. Atk if the holder is hit with a Water-type attack. It can only be used once.", evoEffects: [], category: .heldItems),
        
        Item(name: "Adamant Mint", desc: "When a Pokémon smells this mint, its Attack will grow more easily, but its Sp. Atk will grow more slowly. In other words, this Pokémon's stats will be recalculated using the Adamant nature.", evoEffects: [], category: .enhancer),
        
        Item(name: "Adamant Orb", desc: "A brightly gleaming orb to be held by Dialga. It boosts the power of Dragon- and Steel-type moves by 20% when it is held.", evoEffects: [], category: .heldItems),
        
        Item(name: "Adrenaline Orb", desc: "If held by a Pokémon, it boosts Speed when intimidated but can be used only once. Using it in battle makes wild Pokémon in Alola call for help a number of times.", evoEffects: [], category: .heldItems),
        
        Item(name: "Aerodactylite", desc: "One of a variety of mysterious Mega Stones. Have Aerodactyl hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Aggronite", desc: "One of a variety of mysterious Mega Stones. Have Aggron hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Aguav Berry", desc: "If held by a Pokémon, it restores 33% of the user’s max HP if it falls below 1/4 its max, but it will cause confusion if the user's nature causes Sp. Def to grow more slowly.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Air Balloon", desc: "An item to be held by a Pokémon. The holder will float in the air and be immune to Ground-type attacks until hit. Once the holder is hit, this item will burst.", evoEffects: [], category: .heldItems),
        
        Item(name: "Alakazite", desc: "One of a variety of mysterious Mega Stones. Have Alakazam hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Aloraichium Z", desc: "It converts Z-Power into crystals that upgrade Raichu-Alola’s Thunderbolt to an exclusive Z-Move, Stoked Sparksurfer", evoEffects: [], category: .zcrystals),
        
        Item(name: "Altarianite", desc: "One of a variety of mysterious Mega Stones. Have Altaria hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Ampharosite", desc: "One of a variety of mysterious Mega Stones. Have Ampharos hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Amulet Coin", desc: "An item to be held by a Pokémon. It doubles any prize money received if the holding Pokémon joins a battle.", evoEffects: [], category: .heldItems),
        
        Item(name: "Antidote", desc: "A spray-type medicine for treating poisoning. It can be used to lift the effects of being poisoned from a single Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Apicot Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, its Sp. Def stat will increase by 1 stage when its HP falls below 1/4 its max.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Armor Fossil", desc: "A fossil from a prehistoric Pokémon that once lived on the land. It looks to be from some kind of protective collar. It can be revived into Shieldon", evoEffects: [], category: .fossils),
        
        Item(name: "Armorite Ore", desc: "Rare ore that can be obtained on the Isle of Armor. Something good will happen if you give it to a collector on the Isle of Armor.", evoEffects: [], category: .treasures),
        
        Item(name: "Aspear Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can recover from being frozen on its own in battle.", evoEffects: [], category: .medicine),
        
        Item(name: "Assault Vest", desc: "An item to be held by a Pokémon. This offensive vest boosts Sp. Def by 1.5x but prevents the use of status moves.", evoEffects: [], category: .heldItems),
        
        Item(name: "Audinite", desc: "One of a variety of mysterious Mega Stones. Have Audino hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Awakening", desc: "A spray-type medicine to wake the sleeping. It can be used to rouse a single Pokémon from the clutches of sleep.", evoEffects: [], category: .medicine),
        
        Item(name: "Babiri Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one supereffective Steel-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Bach's Food Tin", desc: "One of the many ingredients that can be used for cooking at your camp. The tinned food that Bach sells is curiously popular in Galar.", evoEffects: [], category: .ingredients),
        
        Item(name: "Balm Mushroom", desc: "A rare mushroom that gives off a nice fragrance. It can be sold at a high price to shops.", evoEffects: [], category: .treasures),
        
        Item(name: "Banettite", desc: "One of a variety of mysterious Mega Stones. Have Banette hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Beach Glass", desc: "A piece of colored glass. Waves have rounded its edges. It’s slightly rough to the touch.", evoEffects: [], category: .treasures),
        
        Item(name: "Beast Ball", desc: "A somewhat different Poké Ball that has a high success rate for catching Ultra Beasts. It has a low success rate for catching other Pokémon.", evoEffects: [], category: .pokeBalls),
        
        Item(name: "Beedrillite", desc: "One of a variety of mysterious Mega Stones. Have Beedrill hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Belue Berry", desc: "Used to make Pokéblocks that will enhance your Beauty, this Berry is rare in other regions.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Berry Juice", desc: "A 100 percent pure juice made of Berries. It can be used to restore 20 HP to a single Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Berry Sweet", desc: "A berry-shaped sweet. When a Milcery holds this, it spins around happily and can evolve into Berry Flavor Alcremie", evoEffects: ["Milcery"], category: .evolution),
        
        Item(name: "Big Malasada", desc: "The Alola region’s local specialty—fried bread. It can be used once to heal all the status conditions of a Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Big Mushroom", desc: "A very large and rare mushroom. It’s popular with a certain class of collectors.", evoEffects: [], category: .treasures),
        
        Item(name: "Big Nugget", desc: "A big nugget of pure gold that gives off a lustrous gleam. It can be sold at a high price to shops.", evoEffects: [], category: .treasures),
        
        Item(name: "Big Pearl", desc: "A rather large pearl that has a very nice silvery sheen. It can be sold at a high price to shops.", evoEffects: [], category: .treasures),
        
        Item(name: "Big Root", desc: "An item to be held by a Pokémon. It boosts the amount of HP the holder restores from HP-stealing moves by 1.3x.", evoEffects: [], category: .heldItems),
        
        Item(name: "Binding Band", desc: "An item to be held by a Pokémon. It’s a band that increases the power of binding moves used by the holder to deal 1/6 of the opposing Pokémon's max HP per turn rather than 1/8.", evoEffects: [], category: .heldItems),
        
        Item(name: "Black Apricorn", desc: "A black Apricorn. It has a scent beyond one’s experience. It can be made into a Heavy Ball.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Black Belt", desc: "An item to be held by a Pokémon. This belt helps the wearer to focus and boosts the power of Fighting-type moves by 20%.", evoEffects: [], category: .heldItems),
        
        Item(name: "Black Flute", desc: "A flute made from black glass. It makes it easier to encounter strong Pokémon in the place you use it. A maniac will buy it for a high price.", evoEffects: [], category: .treasures),
        
        Item(name: "Black Glasses", desc: "An item to be held by a Pokémon. It’s a pair of shady-looking glasses that boost the power of Dark-type moves by 20%.", evoEffects: [], category: .heldItems),
        
        Item(name: "Black Sludge", desc: "An item to be held by a Pokémon. It restores 1/16 of a Pokémon's max HP per turn if it is Poison-type. It damages any other type by 1/8 of its max HP every turn.", evoEffects: [], category: .heldItems),
        
        Item(name: "Blastoisinite", desc: "One of a variety of mysterious Mega Stones. Have Blastoise hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Blazikenite", desc: "One of a variety of mysterious Mega Stones. Have Blaziken hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Blue Apricorn", desc: "A blue Apricorn. It smells a bit like grass. It can be made into a Lure Ball.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Blue Flute", desc: "A flute made from blue glass. It awakens sleeping Pokémon. A maniac will buy it for a high price.", evoEffects: [], category: .treasures),
        
        Item(name: "Blue Scarf", desc: "An item to be held by a Pokémon. During a contest, it raises the Beauty aspect of the Pokémon holding it.", evoEffects: [], category: .heldItems),
        
        Item(name: "Blue Shard", desc: "A small blue shard. It appears to be a fragment of some sort of implement made long ago. It can be exchanged with different people in different regions for items or services.", evoEffects: [], category: .treasures),
        
        Item(name: "Bluk Berry", desc: "Used to make Pokéblocks that will enhance your Beauty. Its blue flesh is dry when eaten.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Blunder Policy", desc: "Raises Speed by two stages when a Pokémon misses with a move because of accuracy.", evoEffects: [], category: .heldItems),
        
        Item(name: "Bob's Food Tin", desc: "One of the many ingredients that can be used for cooking at your camp. The tinned food that Bob sells is curiously popular in Galar.", evoEffects: [], category: .ingredients),
        
        Item(name: "Boiled Egg", desc: "One of the many ingredients that can be used for cooking at your camp. Even just one boiled egg can really enhance a dish.", evoEffects: [], category: .ingredients),
        
        Item(name: "Bold Mint", desc: "When a Pokémon smells this mint, its Defense will grow more easily, but its Attack will grow more slowly. In other words, this Pokémon's stats will be recalculated using the Bold nature.", evoEffects: [], category: .enhancer),
        
        Item(name: "Bottle Cap", desc: "A beautiful bottle cap that gives off a silver gleam. Some people are happy to receive one. It will maximize one IV of a Pokémon in Hyper Training.", evoEffects: [], category: .enhancer),
        
        Item(name: "Brave Mint", desc: "When a Pokémon smells this mint, its Attack will grow more easily, but its Speed will grow more slowly. In other words, this Pokémon's stats will be recalculated using the Brave nature.", evoEffects: [], category: .enhancer),
        
        Item(name: "Bread", desc: "One of the many ingredients that can be used for cooking at your camp. An indispensable tool for mopping up that extra curry left on your plate.", evoEffects: [], category: .ingredients),
        
        Item(name: "Bright Powder", desc: "An item to be held by a Pokémon. It casts a tricky glare that lowers the opposing Pokémon’s accuracy by 10%.", evoEffects: [], category: .heldItems),
        
        Item(name: "Brittle Bones", desc: "One of the many ingredients that can be used for cooking at your camp. The taste boiled off from the bones is sure to give a dish a light umami taste.", evoEffects: [], category: .ingredients),
        
        Item(name: "Bug Gem", desc: "A gem with an insect-like essence. When held, it strengthens the power of a Bug-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Bug Memory", desc: "A memory disc that contains Bug-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Bug.", evoEffects: [], category: .heldItems),
        
        Item(name: "Buginium Z", desc: "It converts Z-Power into crystals that upgrade Bug-type moves to the Bug-type Z-Move Savage Spin-Out.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Burn Drive", desc: "A cassette to be held by Genesect. It changes Genesect’s Techno Blast move so it becomes Fire type.", evoEffects: [], category: .heldItems),
        
        Item(name: "Burn Heal", desc: "A spray-type medicine for treating burns. It can be used to heal a single Pokémon suffering from a burn.", evoEffects: [], category: .medicine),
        
        Item(name: "Calcium", desc: "A nutritious drink for Pokémon. When consumed, it raises the Sp. Atk EVs of a single Pokémon by 10.", evoEffects: [], category: .enhancer),
        
        Item(name: "Calm Mint", desc: "When a Pokémon smells this mint, its Sp. Def will grow more easily, but its Attack will grow more slowly. In other words, this Pokémon's stats will be recalculated using the Calm nature.", evoEffects: [], category: .enhancer),
        
        Item(name: "Cameruptite", desc: "One of a variety of mysterious Mega Stones. Have Camerupt hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Carbos", desc: "A nutritious drink for Pokémon. When consumed, it raises the Speed EVs of a single Pokémon by 10.", evoEffects: [], category: .enhancer),
        
        Item(name: "Careful Mint", desc: "When a Pokémon smells this mint, its Sp. Def will grow more easily, but its Sp. Atk will grow more slowly. In other words, this Pokémon's stats will be recalculated using the Careful nature.", evoEffects: [], category: .enhancer),
        
        Item(name: "Carrot Seeds", desc: "Seeds to plant in a field. The kind of carrot you’ll get (Iceroot Carrots or Shaderoot Carrots) is determined by which field you plant the seeds in (Snowslide Slope or Old Cemetery).", evoEffects: [], category: .keyItems),
        
        Item(name: "Casteliacone", desc: "Castelia City’s specialty, soft-serve ice cream. It can be used once to heal all the status conditions of a Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Cell Battery", desc: "An item to be held by a Pokémon. It boosts Attack by one stage if the holder is hit with an Electric-type attack. It can only be used once.", evoEffects: [], category: .heldItems),
        
        Item(name: "Chalky Stone", desc: "A small whitish stone picked up at the edge of the road.", evoEffects: [], category: .treasures),
        
        Item(name: "Charcoal", desc: "An item to be held by a Pokémon. It’s a combustible fuel that boosts the power of Fire-type moves by 20%.", evoEffects: [], category: .heldItems),
        
        Item(name: "Charizardite X", desc: "One of a variety of mysterious Mega Stones. Have Charizard hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Charizardite Y", desc: "One of a variety of mysterious Mega Stones. Have Charizard hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Charti Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one supereffective Rock-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Cheri Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can recover from paralysis on its own in battle.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Cherish Ball", desc: "A quite rare Poké Ball that has been crafted in order to commemorate a special occasion of some sort.", evoEffects: [], category: .pokeBalls),
        
        Item(name: "Chesto Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can recover from sleep on its own in battle.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Chilan Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one Normal-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Chill Drive", desc: "A cassette to be held by Genesect. It changes Genesect’s Techno Blast move so it becomes Ice type.", evoEffects: [], category: .heldItems),
        
        Item(name: "Chipped Pot", desc: "A peculiar teapot that can make authentic Sinistea evolve into Polteageist. It may be chipped, but tea poured from it is delicious.", evoEffects: ["Sinistea"], category: .evolution),
        
        Item(name: "Choice Band", desc: "An item to be held by a Pokémon. This curious headband boosts Attack by 1.5x but only allows the use of one move.", evoEffects: [], category: .heldItems),
        
        Item(name: "Choice Scarf", desc: "An item to be held by a Pokémon. This curious scarf boosts Speed by 1.5x but only allows the use of one move.", evoEffects: [], category: .heldItems),
        
        Item(name: "Choice Specs", desc: "An item to be held by a Pokémon. These curious glasses boost Sp. Atk by 1.5x but only allow the use of one move.", evoEffects: [], category: .heldItems),
        
        Item(name: "Chople Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one supereffective Fighting-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Claw Fossil", desc: "A fossil from a prehistoric Pokémon that once lived in the sea. It appears to be a fragment of a claw. It can be revived into Anorith", evoEffects: [], category: .fossils),
        
        Item(name: "Cleanse Tag", desc: "An item to be held by a Pokémon. It helps keep wild Pokémon away if the holder is the head of the party.", evoEffects: [], category: .heldItems),
        
        Item(name: "Clever Wing", desc: "An item for use on a Pokémon. It increases the Sp. Def EV of a single Pokémon by 1.", evoEffects: [], category: .enhancer),
        
        Item(name: "Clover Sweet", desc: "A clover-shaped sweet. When a Milcery holds this, it spins around happily and can evolve into Clover Flavor Alcremie", evoEffects: ["Milcery"], category: .evolution),
        
        Item(name: "Coba Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one supereffective Flying-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Coconut Milk", desc: "One of the many ingredients that can be used for cooking at your camp. The refined sweetness of this coconut milk makes it quite popular.", evoEffects: [], category: .ingredients),
        
        Item(name: "Colbur Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one supereffective Dark-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Colress Machine", desc: "A special device that wrings out the potential of Pokémon. It’s an imperfect prototype. It can be used to forcibly awaken sleeping Pokémon.", evoEffects: [], category: .keyItems),
        
        Item(name: "Comet Shard", desc: "A shard that fell to the ground when a comet approached. It can be sold at a high price to shops.", evoEffects: [], category: .treasures),
        
        Item(name: "Cornn Berry", desc: "Used to make Pokéblocks that will enhance your Beauty, this Berry is rare in other regions. A maniac will buy it for a high price", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Courage Candy", desc: "A candy that is packed with energy. When given to a Pokémon, it will increase that Pokémon’s Sp. Def stat by 1.", evoEffects: [], category: .enhancer),
        
        Item(name: "Courage Candy L", desc: "A big candy that is packed with energy. When given to a Pokémon at Lv. 30 or higher, it will increase that Pokémon’s Sp. Def stat.", evoEffects: [], category: .enhancer),
        
        Item(name: "Courage Candy XL", desc: "A huge candy that is packed with energy. When given to a Pokémon at Lv. 60 or higher, it will increase that Pokémon’s Sp. Def stat.", evoEffects: [], category: .enhancer),
        
        Item(name: "Cover Fossil", desc: "A fossil from a prehistoric Pokémon that once lived in the sea. It appears as though it could be part of its back. It can be revived into Tirtouga.", evoEffects: [], category: .fossils),
        
        Item(name: "Cracked Pot", desc: "A peculiar teapot that can make make counterfeit Sinistea evolve into Polteageist. It may be cracked, but tea poured from it is delicious.", evoEffects: ["Sinistea"], category: .evolution),
        
        Item(name: "Custap Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it will be able to move first in its priority bracket just once when its HP falls to 1/4 its max or less.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Damp Mulch", desc: "A fertilizer for growing Berries. However, it appears to be unsuitable for the soil in the Hoenn region and has no effect. A maniac will buy it for a high price.", evoEffects: [], category: .treasures),
        
        Item(name: "Damp Rock", desc: "An item to be held by a Pokémon. It extends the duration of the move Rain Dance from 8 turns to 5 when used by the holder.", evoEffects: [], category: .heldItems),
        
        Item(name: "Dark Gem", desc: "A gem with an essence of darkness. When held, it strengthens the power of a Dark-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Dark Memory", desc: "A memory disc that contains Dark-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Dark.", evoEffects: [], category: .heldItems),
        
        Item(name: "Darkinium Z", desc: "It converts Z-Power into crystals that upgrade Dark-type moves to the Dark-type Z-Move Black Hole Eclipse.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Dawn Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It sparkles like a glittering eye. Only male Kirlia and female Snorunt can evolve using this stone.", evoEffects: ["Kirlia", "Snorunt"], category: .evolution),
        
        Item(name: "Decidium Z", desc: "It converts Z-Power into crystals that upgrade Decidueye’s Spirit Shackle to an exclusive Z-Move, Sinister Arrow Raid.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Deep Sea Scale", desc: "An item to be held by Clamperl. When held and traded, Clamperl will evolve into Gorebyss. This scale shines with a faint pink and doubles the holder’s Sp. Def stat.", evoEffects: ["Clamperl"], category: .heldItems),
        
        Item(name: "Deep Sea Tooth", desc: "An item to be held by Clamperl. When held and traded, Clamperl will evolve into Huntail. This scale shines with a faint pink and doubles the holder’s Sp. Atk stat.", evoEffects: ["Clamperl"], category: .heldItems),
        
        Item(name: "Destiny Knot", desc: "An item to be held by a Pokémon. If the holder becomes infatuated, the opposing Pokémon will be, too. Outside of battle, if held by a Pokémon in a Day Care or Nursery, five of the parents' combined twelve IVs will be passed down to the offspring Pokémon.", evoEffects: [], category: .heldItems),
        
        Item(name: "Diancite", desc: "One of a variety of mysterious Mega Stones. Have Diancie hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Dire Hit", desc: "An item that greatly raises the critical-hit ratio of a Pokémon during a battle by 1 stage. It can be used only once and wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle),
        
        Item(name: "Dire Hit 2", desc: "It can be used many times to raise the critical-hit ratio of one Pokémon by 2 stages. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle),
        
        Item(name: "Dire Hit 3", desc: "It can be used many times to raise the critical-hit ratio of one Pokémon by 3 stages. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle),
        
        Item(name: "Discount Coupon", desc: "This special coupon allows you to buy items at a 50% discount when you are shopping at a boutique.", evoEffects: [], category: .keyItems),
        
        Item(name: "Dive Ball", desc: "A somewhat different Poké Ball that works especially well when catching Pokémon that live underwater.", evoEffects: [], category: .pokeBalls),
        
        Item(name: "DNA Splicers", desc: "A splicer that fuses Kyurem to, and seperates Kyurem from, Reshiram or Zekrom. They are said to have been one in the beginning.", evoEffects: [], category: .keyItems),
        
        Item(name: "Dome Fossil", desc: "A fossil from a prehistoric Pokémon that once lived in the sea. It could be a shell or carapace. It can be revived into Kabuto.", evoEffects: [], category: .fossils),
        
        Item(name: "Douse Drive", desc: "A cassette to be held by Genesect. It changes Genesect’s Techno Blast move so it becomes Water type.", evoEffects: [], category: .heldItems),
        
        Item(name: "Draco Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Dragon-type moves by 20%. When held by Arceus, it changes the type of Arceus and the move Judgement to Dragon.", evoEffects: [], category: .heldItems),
        
        Item(name: "Dragon Fang", desc: "An item to be held by a Pokémon. This hard and sharp fang boosts the power of Dragon-type moves by 20%.", evoEffects: [], category: .heldItems),
        
        Item(name: "Dragon Gem", desc: "A gem with a draconic essence. When held, it strengthens the power of a Dragon-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Dragon Memory", desc: "A memory disc that contains Dragon-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Dragon.", evoEffects: [], category: .heldItems),
        
        Item(name: "Dragon Scale", desc: "A very tough and inflexible scale. Dragon-type Pokémon may be holding this item when caught. If Seadra is traded while holding a Dragon Scale, it will evolve into Kingdra.", evoEffects: ["Seadra"], category: .evolution),
        
        Item(name: "Dragonium Z", desc: "It converts Z-Power into crystals that upgrade Dragon-type moves to the Dragon-type Z-Move Devastating Drake.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Dread Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Dark-type moves by 20%. When held by Arceus, it changes the type of Arceus and the move Judgement to Dark.", evoEffects: [], category: .heldItems),
        
        Item(name: "Dream Ball", desc: "A somewhat different Poké Ball that makes it easier to catch wild Pokémon while they’re asleep.", evoEffects: [], category: .pokeBalls),
        
        Item(name: "Dropped Item", desc: "The Xtransceiver found at the Nimbasa City amusement park. It seems it belongs to a boy.", evoEffects: [], category: .keyItems),
        
        Item(name: "Dubious Disc", desc: "A transparent device overflowing with dubious data. Its producer is unknown. When Porygon2 is traded with this item, it will evolve into Porygon-Z.", evoEffects: ["Porygon2"], category: .evolution),
        
        Item(name: "Durin Berry", desc: "Used to make Pokéblocks that will enhance your Cleverness, this Berry is rare in other regions.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Dusk Ball", desc: "A somewhat different Poké Ball that makes it easier to catch wild Pokémon at night or in dark places such as caves.", evoEffects: [], category: .pokeBalls),
        
        Item(name: "Dusk Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It holds shadows as dark as can be.", evoEffects: ["Murkrow", "Misdreavus", "Lampent", "Doublade"], category: .evolution),
        
        Item(name: "Dynamax Candy", desc: "A candy that is packed with energy. When consumed, it will raise the Dynamax Level of a single Pokémon by one. A higher level means higher HP when Dynamaxed.", evoEffects: [], category: .enhancer),
        
        Item(name: "Dynite Ore", desc: "Mysterious ore that can be obtained in the Max Lair. Something good will happen if you give it to a collector in the Crown Tundra.", evoEffects: [], category: .treasures),
        
        Item(name: "Earth Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Ground-type moves by 20%. When held by Arceus, it changes the type of Arceus and the move Judgement to Ground.", evoEffects: [], category: .heldItems),
        
        Item(name: "Eevium Z", desc: "It converts Z-Power into crystals that upgrade Eevee’s Last Resort to an exclusive Z-Move, Extreme Evoboost.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Eject Button", desc: "An item to be held by a Pokémon. If the holder is hit by an attack, it will be switched out of battle.", evoEffects: [], category: .heldItems),
        
        Item(name: "Eject Pack", desc: "An item to be held by a Pokémon. When the holder’s stats are lowered, it will be switched out of battle.", evoEffects: [], category: .heldItems),
        
        Item(name: "Electirizer", desc: "A box packed with a tremendous amount of electric energy. It’s loved by a certain Pokémon. When Electabuzz is traded with it, it will evolve into Electivire.", evoEffects: ["Electabuzz"], category: .evolution),
        
        Item(name: "Electric Gem", desc: "A gem with an essence of electricity. When held, it strengthens the power of an Electric-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Electric Memory", desc: "A memory disc that contains Electric-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Electric.", evoEffects: [], category: .heldItems),
        
        Item(name: "Electric Seed", desc: "An item to be held by a Pokémon. It boosts Defense on Electric Terrain. It can only be used once.", evoEffects: [], category: .heldItems),
        
        Item(name: "Electrium Z", desc: "It converts Z-Power into crystals that upgrade Electric-type moves to the Electric-type Z-Move Gigavolt Havoc.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Elevator Key", desc: "A card key that activates the elevator in Lysandre Labs. It is emblazoned with Team Flare’s logo.", evoEffects: [], category: .keyItems),
        
        Item(name: "Elixir", desc: "This medicine can be used to restore 10 PP to each of the moves that have been learned by a Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Energy Powder", desc: "A very bitter medicinal powder. It can be used to restore 60 HP to a single Pokémon but will lower its friendship by either 5 or 10 points, depending on whether its current friendship is less or more than 200.", evoEffects: [], category: .medicine),
        
        Item(name: "Energy Root", desc: "An extremely bitter medicinal root. It can be used to restore 120 HP to a single Pokémon but will lower its friendship by either 10 or 15 points, depending on whether its current friendship is less or more than 200.", evoEffects: [], category: .medicine),
        
        Item(name: "Enigma Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, being hit by a supereffective attack will restore 1/4 of its max HP.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Escape Rope", desc: "A long and durable rope. Use it to escape instantly from locations like caves or dungeons. It can be used any number of times.", evoEffects: [], category: .keyItems),
        
        Item(name: "Ether", desc: "This medicine can be used to restore 10 PP to a single selected move that has been learned by a Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Everstone", desc: "An item to be held by a Pokémon. A Pokémon holding this peculiar stone is prevented from evolving.", evoEffects: [], category: .heldItems),
        
        Item(name: "Eviolite", desc: "A mysterious evolutionary lump. When held by a Pokémon that can still evolve, it boosts both Defense and Sp. Def by 1.5x.", evoEffects: [], category: .heldItems),
        
        Item(name: "Exp. Candy L", desc: "A candy that is packed with energy. When consumed, it will grant a single Pokémon 10,000 Exp. Points.", evoEffects: [], category: .enhancer),
        
        Item(name: "Exp. Candy M", desc: "A candy that is packed with energy. When consumed, it will grant a single Pokémon 3,000 Exp. Points.", evoEffects: [], category: .enhancer),
        
        Item(name: "Exp. Candy S", desc: "A candy that is packed with energy. When consumed, it will grant a single Pokémon 800 Exp. Points.", evoEffects: [], category: .enhancer),
        
        Item(name: "Exp. Candy XL", desc: "A candy that is packed with energy. When consumed, it will grant a single Pokémon 30,000 Exp. Points.", evoEffects: [], category: .enhancer),
        
        Item(name: "Exp. Candy XS", desc: "A candy that is packed with energy. When consumed, it will grant a single Pokémon 100 Exp. Points.", evoEffects: [], category: .enhancer),
        
        Item(name: "Exp. Share", desc: "Turning on this special device will allow all the Pokémon on your team to receive Exp. Points from battles.", evoEffects: [], category: .keyItems),
        
        Item(name: "Expert Belt", desc: "An item to be held by a Pokémon. It’s a well-worn belt that boosts the power of supereffective moves by 1.2x.", evoEffects: [], category: .heldItems),
        
        Item(name: "Fairium Z", desc: "It converts Z-Power into crystals that upgrade Fairy-type moves to the Fairy-type Z-Move Twinkle Tackle.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Fairy Gem", desc: "A gem with an essence of the fey. When held, it strengthens the power of a Fairy-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Fairy Memory", desc: "A memory disc that contains Fairy-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Fairy.", evoEffects: [], category: .heldItems),
        
        Item(name: "Fancy Apple", desc: "One of the many ingredients that can be used for cooking at your camp. An apple chosen above others. It has spectacular form and a brilliant sheen.", evoEffects: [], category: .ingredients),
        
        Item(name: "Fast Ball", desc: "A Poké Ball that makes it easier to catch Pokémon that are usually very quick to run away.", evoEffects: [], category: .pokeBalls),
        
        Item(name: "Festival Ticket", desc: "A ticket that allows you to host a mission in Festival Plaza.", evoEffects: [], category: .keyItems),
        
        Item(name: "Fighting Gem", desc: "A gem with an essence of combat. When held, it strengthens the power of a Fighting-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Fighting Memory", desc: "A memory disc that contains Fighting-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Fighting.", evoEffects: [], category: .heldItems),
        
        Item(name: "Fightinium Z", desc: "It converts Z-Power into crystals that upgrade Fighting-type moves to the Fighting-type Z-Move All-Out Pummeling.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Figy Berry", desc: "If held by a Pokémon, it restores the 1/3 of the user’s max HP when it falls to 1/4 its max or lower, but it will cause confusion if the user has a -Attack nature.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Fire Gem", desc: "A gem with an essence of fire. When held, it strengthens the power of a Fire-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Fire Memory", desc: "A memory disc that contains Fire-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Fire.", evoEffects: [], category: .heldItems),
        
        Item(name: "Fire Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. The stone has a fiery orange heart.", evoEffects: ["Vulpix", "Growlithe", "Eevee", "Pansear"], category: .evolution),
        
        Item(name: "Firium Z", desc: "It converts Z-Power into crystals that upgrade Fire-type moves to the Fire-type Z-Move Inferno Overdrive.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Fist Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Fighting-type moves by 20%. When held by Arceus, it changes the type of Arceus and the move Judgement to Fighting.", evoEffects: [], category: .heldItems),
        
        Item(name: "Flame Orb", desc: "An item to be held by a Pokémon. It’s a bizarre orb that will attempt to afflict the holder with a burn after every turn during battle.", evoEffects: [], category: .heldItems),
        
        Item(name: "Flame Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Fire-type moves by 20%. When held by Arceus, it changes the type of Arceus and the move Judgement to Fire.", evoEffects: [], category: .heldItems),
        
        Item(name: "Float Stone", desc: "An item to be held by a Pokémon. This very light stone reduces the weight of a Pokémon by half when held.", evoEffects: [], category: .heldItems),
        
        Item(name: "Flower Sweet", desc: "A flower-shaped sweet. When a Milcery holds this, it spins around happily and can evolve into Flower Flavor Alcremie.", evoEffects: ["Milcery"], category: .evolution),
        
        Item(name: "Fluffy Tail", desc: "A toy that attracts the attention of a Pokémon. It guarantees escape from any battle with wild Pokémon.", evoEffects: [], category: .battle),
        
        Item(name: "Flying Gem", desc: "A gem with an essence of air. When held, it strengthens the power of a Flying-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Flying Memory", desc: "A memory disc that contains Flying-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Flying.", evoEffects: [], category: .heldItems),
        
        Item(name: "Flyinium Z", desc: "It converts Z-Power into crystals that upgrade Flying-type moves to the Flying-type Z-Move Supersonic Skystrike.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Focus Band", desc: "An item to be held by a Pokémon. The holder has a 10% chance to endure a potential KO attack, leaving it with just 1 HP.", evoEffects: [], category: .heldItems),
        
        Item(name: "Focus Sash", desc: "An item to be held by a Pokémon. If the holder has full HP, it will endure a potential KO attack with 1 HP. The item then disappears.", evoEffects: [], category: .heldItems),
        
        Item(name: "Fossilized Bird", desc: "The fossil of an ancient Pokémon that once soared through the sky. What it looked like is a mystery. It can be revived into Dracozolt when paired with a Fossilized Drake or Arctozolt when paired with a Fossilized Dino.", evoEffects: [], category: .fossils),
        
        Item(name: "Fossilized Dino", desc: "The fossil of an ancient Pokémon that once lived in the sea. What it looked like is a mystery. It can be revived into Arctovish when paired with a Fossilized Fish or Arctozolt when paired with a Fossilized Bird.", evoEffects: [], category: .fossils),
        
        Item(name: "Fossilized Drake", desc: "The fossil of an ancient Pokémon that once roamed the land. What it looked like is a mystery. It can be revived into Dracozolt when paired with a Fossilized Bird or Dracovish when paired with a Fossilized Fish.", evoEffects: [], category: .fossils),
        
        Item(name: "Fossilized Fish", desc: "The fossil of an ancient Pokémon that once lived in the sea. What it looked like is a mystery. It can be revived into Dracovish when paired with a Fossilized Drake or Arctovish when paired with a Fossilized Dino.", evoEffects: [], category: .fossils),
        
        Item(name: "Fresh Cream", desc: "One of the many ingredients that can be used for cooking at your camp. Add some whipped cream to a spicy curry to give it some sweetness.", evoEffects: [], category: .ingredients),
        
        Item(name: "Fresh Water", desc: "Water with high mineral content. It can be used to restore 30 HP to a single Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Fried Food", desc: "One of the many ingredients that can be used for cooking at your camp. It’s been a while since it was fried, so it’s gotten greasy.", evoEffects: [], category: .ingredients),
        
        Item(name: "Friend Ball", desc: "A strange Poké Ball that will make the wild Pokémon caught with it more friendly toward you immediately.", evoEffects: [], category: .pokeBalls),
        
        Item(name: "Fruit Bunch", desc: "One of the many ingredients that can be used for cooking at your camp. The syrupy fruits give off a strong tropical feel.", evoEffects: [], category: .ingredients),
        
        Item(name: "Full Heal", desc: "A spray-type medicine that is broadly effective. It can be used to heal all the status conditions of a single Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Full Incense", desc: "An item to be held by a Pokémon. This exotic-smelling incense makes the holder bloated and slow moving. Thus, it will move last in its priority bracket. When held by a Snorlax, it will produce Munchlax eggs instead of Snorlax eggs.", evoEffects: [], category: .heldItems),
        
        Item(name: "Full Restore", desc: "A medicine that can be used to fully restore the HP of a single Pokémon and heal any status conditions it has.", evoEffects: [], category: .medicine),
        
        Item(name: "Galarica Cuff", desc: "A cuff made from woven-together Galarica Twigs. Giving it to Slowpoke-Galar makes the Pokémon very happy and evolve into Slowbro-Galar.", evoEffects: ["Slowpoke-Galar"], category: .evolution),
        
        Item(name: "Galarica Twig", desc: "A twig from a species of tree called Galarica that grows in certain areas around the Galar region. It's a material for an accessory for a certain Pokémon. Eight of them can be traded for a Galarica Cuff and 15 of them can be traded for a Galarica Wreath.", evoEffects: [], category: .treasures),
        
        Item(name: "Galarica Wreath", desc: "A wreath made from woven-together Galarica Twigs. Placing it on the head of a Slowpoke-Galar makes the Pokémon very happy and evolve into Galarian Slowking.", evoEffects: ["Slowpoke-Galar"], category: .evolution),
        
        Item(name: "Galladite", desc: "One of a variety of mysterious Mega Stones. Have Gallade hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Ganlon Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, its Defense stat will increase by 1 stage when its HP is 1/4 its max or less.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Garchompite", desc: "One of a variety of mysterious Mega Stones. Have Garchomp hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Gardevoirite", desc: "One of a variety of mysterious Mega Stones. Have Gardevoir hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Gengarite", desc: "One of a variety of mysterious Mega Stones. Have Gengar hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Genius Wing", desc: "An item for use on a Pokémon. It adds one Sp. Atk EV to a single Pokémon.", evoEffects: [], category: .enhancer),
        
        Item(name: "Gentle Mint", desc: "When a Pokémon smells this mint, its Sp. Def will grow more easily, but its Defense will grow more slowly. In other words, this Pokémon's stats will be recalculated using the Gentle nature.", evoEffects: [], category: .enhancer),
        
        Item(name: "Ghost Gem", desc: "A gem with a spectral essence. When held, it strengthens the power of a Ghost-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Ghost Memory", desc: "A memory disc that contains Ghost-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Ghost.", evoEffects: [], category: .heldItems),
        
        Item(name: "Ghostium Z", desc: "It converts Z-Power into crystals that upgrade Ghost-type moves to the Ghost-type Z-Move Never-Ending Nightmare.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Gigantamix", desc: "One of the many ingredients that can be used for cooking at your camp. A mysterious spice. Even a tiny sprinkle is sure to make a curry gigantic.", evoEffects: [], category: .ingredients),
        
        Item(name: "Glalitite", desc: "One of a variety of mysterious Mega Stones. Have Glalie hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Gold Bottle Cap", desc: "A beautiful bottle cap that gives off a golden gleam. Some people are happy to receive one. When used in Hyper Training, it will raise all a Pokémon's IVs to the maximum value of 31.", evoEffects: [], category: .enhancer),
        
        Item(name: "Gold Leaf", desc: "A mysterious gold leaf. No trees with this leaf have been found yet.", evoEffects: [], category: .treasures),
        
        Item(name: "Golden Nanab Berry", desc: "A Berry that calms wild Pokémon you’re trying to catch drastically when given to them. Only found in Pokémon Let's Go.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Golden Pinap Berry", desc: "A Berry that makes you drastically more likely to get an item when given to Pokémon you’re trying to catch. Only found in Pokémon Let's Go.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Golden Razz Berry", desc: "A Berry that makes it drastically easier to catch Pokémon when given to them. Only found in Pokémon Let's Go.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Gooey Mulch", desc: "A fertilizer for growing Berries. However, it appears to be unsuitable for the soil in the Hoenn region and has no effect. A maniac will buy it for a high price. In Generation IV, it makes Berry plants re-grow from dead plants 150% of the usual number of times.", evoEffects: [], category: .treasures),
        
        Item(name: "Grass Gem", desc: "A gem with an essence of nature. When held, it strengthens the power of a Grass-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Grass Memory", desc: "A memory disc that contains Grass-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Grass.", evoEffects: [], category: .heldItems),
        
        Item(name: "Grassium Z", desc: "It converts Z-Power into crystals that upgrade Grass-type moves to the Grass-type Z-Move Bloom Doom.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Grassy Seed", desc: "An item to be held by a Pokémon. It boosts Defense by 1 stage on Grassy Terrain. It can only be used once.", evoEffects: [], category: .heldItems),
        
        Item(name: "Great Ball", desc: "A good, high-performance Poké Ball that provides a higher success rate for catching Pokémon than a standard Poké Ball.", evoEffects: [], category: .pokeBalls),
        
        Item(name: "Green Apricorn", desc: "A green Apricorn. It has a mysterious, aromatic scent. It can be made into a Friend Ball.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Green Scarf", desc: "An item to be held by a Pokémon. During a contest, it raises the Clever aspect of the Pokémon holding it.", evoEffects: [], category: .heldItems),
        
        Item(name: "Green Shard", desc: "A small green shard. It appears to be a fragment of some sort of implement made long ago. It can be exchanged with different people in different regions for items or services.", evoEffects: [], category: .treasures),
        
        Item(name: "Grepa Berry", desc: "A Berry to be consumed by Pokémon. Using it on a Pokémon makes it more friendly by either 2, 5, or 10 points, depending on if the Pokémon's current friendship is 200 or more, 100-199, or less than 100, respectively. It also lowers its Sp. Def EVs by 10.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Grip Claw", desc: "An item to be held by a Pokémon. It extends the duration of multi-turn attacks, such as Bind and Wrap, to 7 turns.", evoEffects: [], category: .heldItems),
        
        Item(name: "Griseous Orb", desc: "A glowing orb to be held by Giratina. It boosts the power of Dragon- and Ghost-type moves by 20% when it is held. It also changes Giratina to its Origin Forme.", evoEffects: [], category: .heldItems),
        
        Item(name: "Ground Gem", desc: "A gem with an essence of land. When held, it strengthens the power of a Ground-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Ground Memory", desc: "A memory disc that contains Ground-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Ground.", evoEffects: [], category: .heldItems),
        
        Item(name: "Groundium Z", desc: "It converts Z-Power into crystals that upgrade Ground-type moves to the Ground-type Z-Move Tectonic Rage.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Growth Mulch", desc: "A fertilizer for growing Berries. However, it appears to be unsuitable for the soil in the Hoenn region and has no effect. A maniac will buy it for a high price.", evoEffects: [], category: .treasures),

        Item(name: "Grubby Hanky", desc: "A handkerchief dropped by a regular at Café Warehouse. It smells faintly like a Pokémon.", evoEffects: [], category: .keyItems),

        Item(name: "Guard Spec.", desc: "An item that prevents stat reduction among the Trainer’s party Pokémon for five turns after it is used in battle.", evoEffects: [], category: .battle),

        Item(name: "Gyaradosite", desc: "One of a variety of mysterious Mega Stones. Have Gyarados hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),

        Item(name: "Haban Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one supereffective Dragon-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Hard Stone", desc: "An item to be held by a Pokémon. It’s a durable stone that boosts the power of Rock-type moves by 20%.", evoEffects: [], category: .heldItems),

        Item(name: "Hasty Mint", desc: "When a Pokémon smells this mint, its Speed will grow more easily, but its Defense will grow more slowly. In other words, its stats will be recalculated using the Hasty nature.", evoEffects: [], category: .enhancer),

        Item(name: "Heal Ball", desc: "A remedial Poké Ball that restores the HP of a Pokémon caught with it and eliminates any status conditions.", evoEffects: [], category: .pokeBalls),

        Item(name: "Heal Powder", desc: "A very bitter medicinal powder. It can be used once to heal all the status conditions of a Pokémon but lowers its Friendship. Friendship is lowered by 5 or 10 points, depending on whether the Pokémon's Friendship is less or more than 200, respectively.", evoEffects: [], category: .medicine),

        Item(name: "Health Candy", desc: "A candy that is packed with energy. When given to a Pokémon, it will increase that Pokémon’s HP stat by 1 in Pokémon Let's Go.", evoEffects: [], category: .enhancer),

        Item(name: "Health Candy L", desc: "A candy that is packed with energy. When given to a Pokémon level 30 or higher, it will increase that Pokémon’s HP stat by 1 in Pokémon Let's Go.", evoEffects: [], category: .enhancer),

        Item(name: "Health Candy XL", desc: "A candy that is packed with energy. When given to a Pokémon level 60 or higher, it will increase that Pokémon’s HP stat by 1 in Pokémon Let's Go.", evoEffects: [], category: .enhancer),

        Item(name: "Health Wing", desc: "An item for use on a Pokémon. It increases the HP EVs of a single Pokémon by 1.", evoEffects: [], category: .enhancer),

        Item(name: "Heart Scale", desc: "A pretty, heart-shaped scale that is extremely rare. Some people are happy to receive one. It can be given to a Move Reminder to teach a move to a Pokémon.", evoEffects: [], category: .treasures),

        Item(name: "Heat Rock", desc: "An item to be held by a Pokémon. It extends the duration of the move Sunny Day to 8 turns instead of 5 when used by the holder.", evoEffects: [], category: .heldItems),

        Item(name: "Heavy Ball", desc: "A Poké Ball that is better than usual at catching very heavy Pokémon.", evoEffects: [], category: .pokeBalls),

        Item(name: "Heavy-Duty Boots", desc: "These boots prevent the effects of traps such as Stealth Rock set on the battlefield.", evoEffects: [], category: .heldItems),

        Item(name: "Helix Fossil", desc: "A fossil from a prehistoric Pokémon that once lived in the sea. It might be a piece of a seashell. It can be revived into Omanyte.", evoEffects: [], category: .fossils),

        Item(name: "Heracronite", desc: "One of a variety of mysterious Mega Stones. Have Heracross hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),

        Item(name: "Hi-tech Earbuds", desc: "Strange earbuds that allow you to freely control the volume of various sounds.", evoEffects: [], category: .keyItems),
        
        Item(name: "HM01", desc: "Teaches the move Cut to a compatible Pokémon.", evoEffects: [], category: .machines, moveName: ["Cut"]),
        
        Item(name: "HM02", desc: "Teaches the move Fly to a compatible Pokémon.", evoEffects: [], category: .machines, moveName: ["Fly"]),
        
        Item(name: "HM03", desc: "Teaches the move Surf to a compatible Pokémon.", evoEffects: [], category: .machines, moveName: ["Surf"]),

        Item(name: "HM04", desc: "Teaches the move Strength to a compatible Pokémon.", evoEffects: [], category: .machines, moveName: ["Strength"]),
        
        Item(name: "HM05", desc: "Teaches a move to compatible Pokémon. In Generations 1-3, it teaches Flash. In Generation 4, it teaches Defog. In Generation 5, it teaches Whirlpool. In Generations 5-7, it teaches Waterfall.", evoEffects: [], category: .machines, moveName: ["Flash", "Defog", "Whirlpool", "Waterfall"]),
        
        Item(name: "HM06", desc: "Teaches a move to compatible Pokémon. In Generation 2, it teaches Whirlpool. In Generations 3-4 and in Omega Ruby and Alpha Sapphire, it teaches Rock Smash. In Generation 5, it teaches Dive.", evoEffects: [], category: .machines, moveName: ["Whirlpool", "Rock Smash", "Dive"]),
        
        Item(name: "HM07", desc: "Teaches a move to compatible Pokémon. In Generations 2-4, it teaches Waterfall. In Omega Ruby and Alpha Sapphire, it teaches Dive.", evoEffects: [], category: .machines, moveName: ["Waterfall", "Dive"]),
        
        Item(name: "HM08", desc: "Teaches a move to compatible Pokémon. In Generation 3, it teaches Dive. In Generation 4, it teaches Rock Climb.", evoEffects: [], category: .machines, moveName: ["Dive", "Rock Climb"]),
        
        Item(name: "Hondew Berry", desc: "A Berry to be consumed by Pokémon. Using it on a Pokémon makes it more friendly by 10 points if its current Friendship is less than 100, by 5 points if its current friendship is between 100-199, or 2 points if its current Friendship is 200 or more. It also lowers the Pokémon's Sp. Atk EV by 10.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Honey", desc: "A sweet honey collected by Pokémon. It has a lush aroma and can be sold at a low price to shops. It attracts wild Pokémon when it is used in tall grass, in caves, or on special trees.", evoEffects: [], category: .treasures),
        
        Item(name: "Honor of Kalos", desc: "A precious symbol that is awarded only to an individual who has done great things for the Kalos region.", evoEffects: [], category: .keyItems),
        
        Item(name: "Houndoominite", desc: "One of a variety of mysterious Mega Stones. Have Houndoom hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "HP Up", desc: "A nutritious drink for Pokémon. When consumed, it raises the HP EV of a single Pokémon by 10.", evoEffects: [], category: .enhancer),
        
        Item(name: "Hyper Potion", desc: "A spray-type medicine for treating wounds. It can be used to restore 120 HP to a single Pokémon.", evoEffects: [], category: .medicine),
        
        Item(name: "Iapapa Berry", desc: "If held by a Pokémon, it restores the user’s HP by 33% if it falls below 1/4 its max, but it will cause confusion if the user's Nature causes its Defense to grow slower.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Ice Gem", desc: "A gem with an essence of ice. When held, it strengthens the power of an Ice-type move by 30% one time.", evoEffects: [], category: .heldItems),
        
        Item(name: "Ice Heal", desc: "A spray-type medicine for treating freezing. It can be used to thaw out a single Pokémon that has been frozen solid.", evoEffects: [], category: .medicine),
        
        Item(name: "Ice Memory", desc: "A memory disc that contains Ice-type data. When held by Silvally, it changes its type, as well as the type of the move Multi-Attack, to Ice.", evoEffects: [], category: .heldItems),
        
        Item(name: "Ice Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It has an unmistakable snowflake pattern.", evoEffects: ["Sandshrew-Alola", "Vulpix-Alola"], category: .evolution),
        
        Item(name: "Iceroot Carrot", desc: "Produce that the King of Bountiful Harvests’ beloved steed likes to eat. It grew in a field covered in snow.", evoEffects: [], category: .keyItems),
        
        Item(name: "Icicle Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Ice-type moves by 20%. When held by Arceus, it changes the type of Arceus and the move Judgement to Ice.", evoEffects: [], category: .heldItems),
        
        Item(name: "Icium Z", desc: "It converts Z-Power into crystals that upgrade Ice-type moves to the Ice-type Z-Move Subzero Slammer.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Icy Rock", desc: "An item to be held by a Pokémon. It extends the duration of the move Hail to 8 turns instead of the usual 5 when used by the holder.", evoEffects: [], category: .heldItems),
        
        Item(name: "Impish Mint", desc: "When a Pokémon smells this mint, its Defense will grow more easily, but its Sp. Atk will grow more slowly. In other words, its stats will be recalculated using the Impish nature.", evoEffects: [], category: .enhancer),
        
        Item(name: "Incinium Z", desc: "It converts Z-Power into crystals that upgrade Incineroar’s Darkest Lariat to an exclusive Z-Move, Malicious Moonsault.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Insect Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Bug-type moves by 20%. When held by Arceus, it changes the type of Arceus and the move Judgement to Bug.", evoEffects: [], category: .heldItems),
        
        Item(name: "Instant Noodles", desc: "One of the many ingredients that can be used for cooking at your camp. It has a junk-food sort of taste, but it goes well with curry.", evoEffects: [], category: .ingredients),
        
        Item(name: "Intriguing Stone", desc: "A rather curious stone that might appear valuable to some. It’s all in the eye of the beholder. It is an unidentified Mega Stone.", evoEffects: [], category: .keyItems),
        
        Item(name: "Iron", desc: "A nutritious drink for Pokémon. When consumed, it raises the Defense EV of a single Pokémon by 10.", evoEffects: [], category: .enhancer),
        
        Item(name: "Iron Ball", desc: "An item to be held by a Pokémon. It halves Speed and allows Ground-type moves to hit Flying types and holders that are levitating.", evoEffects: [], category: .heldItems),
        
        Item(name: "Iron Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Steel-type moves by 20%. When held by Arceus, it changes the type of Arceus and the move Judgement to Steel.", evoEffects: [], category: .heldItems),
        
        Item(name: "Item Drop", desc: "When used, it causes an ally Pokémon to drop a held item.", evoEffects: [], category: .battle),
        
        Item(name: "Item Urge", desc: "When used, it causes an ally Pokémon to use its held item.", evoEffects: [], category: .battle),
        
        Item(name: "Jaboca Berry", desc: "A Berry to be consumed by Pokémon. If a physical attack hits the Pokémon holding it, the attacker will lose 1/8 of its max HP.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Jolly Mint", desc: "When a Pokémon smells this mint, its Speed will grow more easily, but its Sp. Atk will grow more slowly. In other words, its stats will be recalculated using the Jolly nature.", evoEffects: [], category: .enhancer),
        
        Item(name: "Kangaskhanite", desc: "One of a variety of mysterious Mega Stones. Have Kangaskhan hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .megaEvolution),
        
        Item(name: "Kasib Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one supereffective Ghost-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Kebia Berry", desc: "If held by a Pokémon, this Berry will half the damage taken from one supereffective Poison-type attack.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Kee Berry", desc: "If held by a Pokémon, this Berry will increase the holder’s Defense by 1 stage if it’s hit with a physical move.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Kelpsy Berry", desc: "A Berry to be consumed by Pokémon. Using it on a Pokémon makes it more friendly by 10 points if the current Friendship is less than 100, by 5 points if the current Friendship is 100-99, or by 2 points if the current Friendship is 200 or more, but lowers its Attack EVs by 10.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "King's Rock", desc: "An item to be held by a Pokémon. When the holder successfully inflicts damage, the target has a 10% to flinch. When Poliwhirl holds the item when traded, it will evolve into Politoed. When Slowpoke holds the item while traded, it will evolve into Slowking.", evoEffects: ["Poliwhirl", "Slowpoke"], category: .evolution),
        
        Item(name: "Kommonium Z", desc: "It converts Z-Power into crystals that upgrade Kommo-o’s Clanging Scales to an exclusive Z-Move, Clangorous Soulblaze.", evoEffects: [], category: .zcrystals),
        
        Item(name: "Lagging Tail", desc: "An item to be held by a Pokémon. It is tremendously heavy and makes the holder move last in its priority bracket.", evoEffects: [], category: .heldItems),
        
        Item(name: "Lansat Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, its critical-hit ratio will increase when its HP is 1/4 its max or less.", evoEffects: [], category: .berriesAndApricorns),
        
        Item(name: "Large Leek", desc: "One of the many ingredients that can be used for cooking at your camp. Whether this is the kind of vegetable stalk that Farfetch’d like is unknown.", evoEffects: [], category: .ingredients),
        
        Item(name: "Latiasite", desc: "One of a variety of mysterious Mega Stones. Have Latias hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Latiosite", desc: "One of a variety of mysterious Mega Stones. Have Latios hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lava Cookie", desc: "Lavaridge Town’s local specialty. It can be used once to heal all the status conditions of a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lax Incense", desc: "An item to be held by a Pokémon. The beguiling aroma of this incense may cause attacks to miss its holder.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lax Mint", desc: "When a Pokémon smells this mint, its Defense will grow more easily, but its Sp. Def will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Leaf Letter", desc: "A letter written on a leaf. Something is written using Pikachu’s/Eevee’s footprints.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Leaf Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It has an unmistakable leaf pattern.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Leek", desc: "An item to be held by Farfetch’d. This very long and stiff stalk of leek boosts its critical-hit ratio.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Leftovers", desc: "An item to be held by a Pokémon. The holder’s HP is slowly but steadily restored throughout every battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lemonade", desc: "A very sweet and refreshing drink. It can be used to restore 70 HP to a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Leppa Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can restore 10 PP to a depleted move during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Level Ball", desc: "A Poké Ball that makes it easier to catch Pokémon that are at a lower level than your own Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Liechi Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, its Attack stat will increase when it’s in a pinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Life Orb", desc: "An item to be held by a Pokémon. It boosts the power of moves but at the cost of some HP on each hit.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Light Ball", desc: "An item to be held by Pikachu. It’s a puzzling orb that boosts its Attack and Sp. Atk stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Light Clay", desc: "An item to be held by a Pokémon. Protective moves like Light Screen and Reflect will be effective longer.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lone Earring", desc: "A single earring that somebody dropped.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lonely Mint", desc: "When a Pokémon smells this mint, its Attack will grow more easily, but its Defense will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Looker Ticket", desc: "A ticket that was handmade by Looker. It’s decorated with a liberal amount of glittery paint.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lopunnite", desc: "One of a variety of mysterious Mega Stones. Have Lopunny hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Love Ball", desc: "A Poké Ball that works best when catching a Pokémon that is of the opposite gender of your Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Love Sweet", desc: "A heart-shaped sweet. When a Milcery holds this, it spins around happily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lucarionite", desc: "One of a variety of mysterious Mega Stones. Have Lucario hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Luck Incense", desc: "An item to be held by a Pokémon. It doubles any prize money received if the holding Pokémon joins a battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lucky Egg", desc: "An item to be held by a Pokémon. It’s an egg filled with happiness that earns the holder extra Exp. Points in battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lucky Punch", desc: "An item to be held by Chansey. This pair of lucky boxing gloves will boost Chansey’s critical-hit ratio.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lum Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can recover from any status condition during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Luminous Moss", desc: "An item to be held by a Pokémon. It boosts Sp. Def if the holder is hit with a Water-type attack. It can only be used once.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lumiose Galette", desc: "A popular treat in Lumiose City. It can be used once to heal all the status conditions of a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lunalium Z", desc: "It converts Z-Power into crystals that upgrade Lunala’s Moongeist Beam to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lure", desc: "A glass bottle of perfume that makes rare Pokémon more likely to appear.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lure Ball", desc: "A Poké Ball that is good for catching Pokémon that you reel in with a rod while out fishing.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lustrous Orb", desc: "A beautifully glowing orb to be held by Palkia. It boosts the power of Dragon- and Water-type moves when it is held.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Luxury Ball", desc: "A particularly comfortable Poké Ball that makes a wild Pokémon quickly grow friendlier after being caught.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Lycanium Z", desc: "It converts Z-Power into crystals that upgrade Lycanroc’s Stone Edge to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Macho Brace", desc: "An item to be held by a Pokémon. This stiff, heavy brace helps Pokémon grow strong but cuts Speed in battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Magmarizer", desc: "A box packed with a tremendous amount of magma energy. It’s loved by a certain Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Magnet", desc: "An item to be held by a Pokémon. It’s a powerful magnet that boosts the power of Electric-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mago Berry", desc: "If held by a Pokémon, it restores the user’s HP in a pinch, but it will cause confusion if the user hates the taste.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Magost Berry", desc: "Used to make Pokéblocks that will enhance your Cuteness, this Berry is rare in other regions.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Manectite", desc: "One of a variety of mysterious Mega Stones. Have Manectric hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Maranga Berry", desc: "If held by a Pokémon, this Berry will increase the holder’s Sp. Def if it’s hit with a special move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Marble", desc: "A round glass marble. You can see colored glass inside the transparent marble.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Marshadium Z", desc: "It converts Z-Power into crystals that upgrade Marshadow’s Spectral Thief to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Master Ball", desc: "The best Poké Ball with the ultimate level of performance. With it, you will catch any wild Pokémon without fail.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mawilite", desc: "One of a variety of mysterious Mega Stones. Have Mawile hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Max Elixir", desc: "This medicine can be used to fully restore the PP of all of the moves that have been learned by a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Max Ether", desc: "This medicine can be used to fully restore the PP of a single selected move that has been learned by a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Max Honey", desc: "", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Max Lure", desc: "A glass bottle of perfume that makes rare Pokémon more likely to appear. It lasts longer than a Super Lure.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Max Mushrooms", desc: "", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Max Potion", desc: "A spray-type medicine for treating wounds. It can be used to completely restore the max HP of a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Max Repel", desc: "An item that prevents any low-level wild Pokémon from jumping out at you for a while. It lasts longer than Super Repel.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Max Revive", desc: "A medicine that can be used to revive a single Pokémon that has fainted. It also fully restores the Pokémon’s max HP.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Meadow Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Grass-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Medichamite", desc: "One of a variety of mysterious Mega Stones. Have Medicham hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mental Herb", desc: "An item to be held by a Pokémon. The holder shakes off move-binding effects to move freely. It can be used only once.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Metagrossite", desc: "One of a variety of mysterious Mega Stones. Have Metagross hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Metal Coat", desc: "An item to be held by a Pokémon. It’s a special metallic film that can boost the power of Steel-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Metal Powder", desc: "An item to be held by Ditto. Extremely fine yet hard, this odd powder boosts the Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Metronome", desc: "An item to be held by a Pokémon. It boosts moves used consecutively but only until a different move is used.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mewnium Z", desc: "It converts Z-Power into crystals that upgrade Mew’s Psychic to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mewtwonite X", desc: "One of a variety of mysterious Mega Stones. Have Mewtwo hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mewtwonite Y", desc: "One of a variety of mysterious Mega Stones. Have Mewtwo hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Micle Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, its accuracy will increase just once when it’s in a pinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mighty Candy", desc: "A candy that is packed with energy. When given to a Pokémon, it will increase that Pokémon’s Attack stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mighty Candy L", desc: "A big candy that is packed with energy. When given to a Pokémon at Lv. 30 or higher, it will increase that Pokémon’s Attack stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mighty Candy XL", desc: "A huge candy that is packed with energy. When given to a Pokémon at Lv. 60 or higher, it will increase that Pokémon’s Attack stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mild Mint", desc: "When a Pokémon smells this mint, its Sp. Atk will grow more easily, but its Defense will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mimikium Z", desc: "It converts Z-Power into crystals that upgrade Mimikyu’s Play Rough to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mind Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Psychic-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Miracle Seed", desc: "An item to be held by a Pokémon. It’s a seed imbued with life-force that boosts the power of Grass-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Misty Seed", desc: "An item to be held by a Pokémon. It boosts Sp. Def on Misty Terrain. It can only be used once.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mixed Mushrooms", desc: "One of the many ingredients that can be used for cooking at your camp. The chewy texture of the mushrooms transforms any dish they’re added to.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Modest Mint", desc: "When a Pokémon smells this mint, its Sp. Atk will grow more easily, but its Attack will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Moomoo Cheese", desc: "One of the many ingredients that can be used for cooking at your camp. Melted cheese can really give a curry some richness.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Moomoo Milk", desc: "A bottle of highly nutritious milk. It can be used to restore 100 HP to a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Moon Ball", desc: "A Poké Ball that will make it easier to catch Pokémon that can evolve using a Moon Stone.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Moon Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It is as black as the night sky.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Muscle Band", desc: "An item to be held by a Pokémon. This headband exudes strength, slightly boosting the power of physical moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Muscle Wing", desc: "An item for use on a Pokémon. It slightly increases the base Attack stat of a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Mystic Water", desc: "An item to be held by a Pokémon. This teardrop-shaped gem boosts the power of Water-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Naive Mint", desc: "When a Pokémon smells this mint, its Speed will grow more easily, but its Sp. Def will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Nanab Berry", desc: "Used to make Pokéblocks that will enhance your Cuteness. Its pink flesh is sweet when eaten.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Naughty Mint", desc: "When a Pokémon smells this mint, its Attack will grow more easily, but its Sp. Def will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Nest Ball", desc: "A somewhat different Poké Ball that becomes more effective the lower the level of the wild Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Net Ball", desc: "A somewhat different Poké Ball that is more effective when attempting to catch Water- or Bug-type Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Never-Melt Ice", desc: "An item to be held by a Pokémon. It’s a heat- repelling piece of ice that boosts the power of Ice-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Nomel Berry", desc: "Used to make Pokéblocks that will enhance your Toughness, this Berry is rare in other regions.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Normal Gem", desc: "A gem with an ordinary essence. When held, it strengthens the power of a Normal-type move one time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Normalium Z", desc: "It converts Z-Power into crystals that upgrade Normal-type moves to Normal-type Z-Moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Nugget", desc: "A nugget of the purest gold that gives off a lustrous gleam in direct light. It can be sold at a high price to shops.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Occa Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Fire-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Odd Incense", desc: "An item to be held by a Pokémon. This exotic-smelling incense boosts the power of Psychic-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Odd Keystone", desc: "A vital item that is needed to keep a stone tower from collapsing. Voices can be heard from it occasionally.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Old Amber", desc: "A piece of amber that still contains the genetic material of an ancient Pokémon. It’s clear with a tawny, reddish tint.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Old Gateau", desc: "The Old Chateau’s hidden specialty. It can be used once to heal all the status conditions of a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Oran Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can restore its own HP by 10 points during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Oval Charm", desc: "An oval charm said to increase the chance of Pokémon Eggs being found at the Nursery.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Oval Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It’s as round as a Pokémon Egg.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pack of Potatoes", desc: "One of the many ingredients that can be used for cooking at your camp. Potatoes help mellow out a spicy taste, to make a dish more mild.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Packaged Curry", desc: "One of the many ingredients that can be used for cooking at your camp. Using packaged curry helps make sure there are no slipups when cooking.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pamtre Berry", desc: "Used to make Pokéblocks that will enhance your Beauty, this Berry is rare in other regions.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Paralyze Heal", desc: "A spray-type medicine for treating paralysis. It can be used to free a single Pokémon that has been paralyzed.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Park Ball", desc: "A special Poké Ball for the Pal Park.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pass Orb", desc: "A mysterious orb containing the power of the Unova region, to be used when generating Pass Power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Passho Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Water-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pasta", desc: "One of the many ingredients that can be used for cooking at your camp. These flour noodles make for a surprisingly good match with curry.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Payapa Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Psychic-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pearl", desc: "A rather small pearl that has a very nice silvery sheen to it. It can be sold at a low price to shops.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pearl String", desc: "Very large pearls that sparkle in a pretty silver color. They can be sold at a high price to shops.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pecha Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can recover from poisoning on its own in battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Permit", desc: "A permit that is needed to enter the Nature Preserve. Not many know about it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Persim Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can recover from confusion on its own in battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Petaya Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, its Sp. Atk stat will increase when it’s in a pinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pewter Crunchies", desc: "Pewter City’s famous crunchy snack. They can be used to heal all status conditions of a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pidgeotite", desc: "One of a variety of mysterious Mega Stones. Have Pidgeot hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pikanium Z", desc: "It converts Z-Power into crystals that upgrade Pikachu’s Volt Tackle to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pikashunium Z", desc: "It converts Z-Power into crystals that upgrade a Thunderbolt by Pikachu in a cap to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pinap Berry", desc: "Used to make Pokéblocks that will enhance your Toughness. Its yellow flesh is sour when eaten.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pink Apricorn", desc: "A pink Apricorn. It has a nice, sweet scent.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pink Nectar", desc: "A flower nectar obtained from the flowering shrubs on Royal Avenue. It changes the form of certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pink Scarf", desc: "An item to be held by a Pokémon. During a contest, it raises the Cute aspect of the Pokémon holding it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pinsirite", desc: "One of a variety of mysterious Mega Stones. Have Pinsir hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pixie Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Fairy-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Plasma Card", desc: "A card key needed to enter the password inside the Plasma Frigate.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Plume Fossil", desc: "A fossil from a prehistoric Pokémon that once lived in the sky. It looks as if it could come from part of its wing.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Poison Barb", desc: "An item to be held by a Pokémon. This small, poisonous barb boosts the power of Poison-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Poison Gem", desc: "A gem with an essence of poison. When held, it strengthens the power of a Poison-type move one time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Poison Memory", desc: "A memory disc that contains Poison-type data. It changes the type of the holder if held by a certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Poisonium Z", desc: "It converts Z-Power into crystals that upgrade Poison-type moves to Poison-type Z-Moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Poké Ball", desc: "A device for catching wild Pokémon. It’s thrown like a ball at a Pokémon, comfortably encapsulating its target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Poké Doll", desc: "A doll that attracts the attention of a Pokémon. It guarantees escape from any battle with wild Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Poké Toy", desc: "A toy that attracts the attention of a Pokémon. It guarantees escape from any battle with wild Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Polished Mud Ball", desc: "A ball made of mud. It had been polished for such a long time that the surface is very shiny.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pomeg Berry", desc: "A Berry to be consumed by Pokémon. Using it on a Pokémon makes it more friendly but lowers its HP base points.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Potion", desc: "A spray-type medicine for treating wounds. It can be used to restore 20 HP to a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Power Anklet", desc: "An item to be held by a Pokémon. It reduces Speed but allows the holder’s Speed stat to grow more after battling.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Power Band", desc: "An item to be held by a Pokémon. It reduces Speed but allows the holder’s Sp. Def stat to grow more after battling.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Power Belt", desc: "An item to be held by a Pokémon. It reduces Speed but allows the holder’s Defense stat to grow more after battling.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Power Bracer", desc: "An item to be held by a Pokémon. It reduces Speed but allows the holder’s Attack stat to grow more after battling.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Power Herb", desc: "A single-use item to be held by a Pokémon. It allows the holder to immediately use a move that normally requires a turn to charge.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Power Lens", desc: "An item to be held by a Pokémon. It reduces Speed but allows the holder’s Sp. Atk stat to grow more after battling.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Power Plant Pass", desc: "This pass serves as an ID card for gaining access to the Power Plant that lies along Route 13.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Power Weight", desc: "An item to be held by a Pokémon. It reduces Speed but allows the holder’s max HP to grow more after battling.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "PP Max", desc: "A medicine that optimally raises the max PP of a single selected move that has been learned by a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "PP Up", desc: "A medicine that slightly raises the max PP of a single selected move that has been learned by a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Precooked Burger", desc: "One of the many ingredients that can be used for cooking at your camp. If you’re unsure about what to cook, you can’t go wrong with some burger.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Premier Ball", desc: "A somewhat rare Poké Ball that was made as a commemorative item used to celebrate an event of some sort.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pretty Wing", desc: "Though this feather is beautiful, it’s just a regular feather and has no effect on Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Primarium Z", desc: "It converts Z-Power into crystals that upgrade Primarina’s Sparkling Aria to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Prism Scale", desc: "A mysterious scale that causes a certain Pokémon to evolve. It shines in rainbow colors.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Prison Bottle", desc: "A bottle believed to have been used to seal away the power of a certain Pokémon long, long ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Prof's Letter", desc: "A letter that Professor Sycamore wrote to your mother. A faint but pleasant perfume seems to cling to the paper.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Protective Pads", desc: "An item to be held by a Pokémon. These pads protect the holder from effects caused by making direct contact with the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Protector", desc: "A protective item of some sort. It is extremely stiff and heavy. It’s loved by a certain Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Protein", desc: "A nutritious drink for Pokémon. When consumed, it raises the Attack base points of a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Psychic Gem", desc: "A gem with an essence of the mind. When held, it strengthens the power of a Psychic-type move one time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Psychic Memory", desc: "A memory disc that contains Psychic-type data. It changes the type of the holder if held by a certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Psychic Seed", desc: "An item to be held by a Pokémon. It boosts Sp. Def on Psychic Terrain. It can only be used once.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Psychium Z", desc: "It converts Z-Power into crystals that upgrade Psychic-type moves to Psychic-type Z-Moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pungent Root", desc: "One of the many ingredients that can be used for cooking at your camp. Though carelessly picked, these herbs can add a fragrant accent to a dish.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Pure Incense", desc: "An item to be held by a Pokémon. It helps keep wild Pokémon away if the holder is the head of the party.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Purple Nectar", desc: "A flower nectar obtained at Poni Meadow. It changes the form of certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Qualot Berry", desc: "A Berry to be consumed by Pokémon. Using it on a Pokémon makes it more friendly but lowers its Defense base points.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Quick Ball", desc: "A somewhat different Poké Ball that has a more successful catch rate if used at the start of a wild encounter.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Quick Candy", desc: "A candy that is packed with energy. When given to a Pokémon, it will increase that Pokémon’s Speed stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Quick Candy L", desc: "A big candy that is packed with energy. When given to a Pokémon at Lv. 30 or higher, it will increase that Pokémon’s Speed stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Quick Candy XL", desc: "A huge candy that is packed with energy. When given to a Pokémon at Lv. 60 or higher, it will increase that Pokémon’s Speed stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Quick Claw", desc: "An item to be held by a Pokémon. This light, sharp claw lets the bearer move first occasionally.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Quick Powder", desc: "An item to be held by Ditto. Extremely fine yet hard, this odd powder boosts the Speed stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Quiet Mint", desc: "When a Pokémon smells this mint, its Sp. Atk will grow more easily, but its Speed will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rabuta Berry", desc: "Used to make Pokéblocks that will enhance your Cleverness, this Berry is rare in other regions.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rage Candy Bar", desc: "Mahogany Town’s famous candy. It can be used once to heal all the status conditions of a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rare Bone", desc: "A rare bone that is extremely valuable for the study of Pokémon archeology. It can be sold for a high price to shops.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rare Candy", desc: "A candy that is packed with energy. When consumed, it will instantly raise the level of a single Pokémon by one.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rash Mint", desc: "When a Pokémon smells this mint, its Sp. Atk will grow more easily, but its Sp. Def will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rawst Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can recover from a burn on its own in battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Razor Claw", desc: "An item to be held by a Pokémon. This sharply hooked claw increases the holder’s critical-hit ratio.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Razor Fang", desc: "An item to be held by a Pokémon. When the holder successfully inflicts damage, the target may also flinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Razz Berry", desc: "Used to make Pokéblocks that will enhance your Coolness. Its red flesh is spicy when eaten.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Reaper Cloth", desc: "A cloth imbued with horrifyingly strong spiritual energy. It’s loved by a certain Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Red Apricorn", desc: "A red Apricorn. It assails your nostrils.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Red Card", desc: "An item to be held by a Pokémon. When the holder is hit by an attack, the attacker is removed from battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Red Flute", desc: "A flute made from red glass. It snaps Pokémon out of infatuation.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Red Nectar", desc: "A flower nectar obtained at Ula’ula Meadow. It changes the form of certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Red Scarf", desc: "An item to be held by a Pokémon. During a contest, it raises the Cool aspect of the Pokémon holding it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Red Shard", desc: "A small red shard. It appears to be a fragment of some sort of implement made long ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Relaxed Mint", desc: "When a Pokémon smells this mint, its Defense will grow more easily, but its Speed will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Relic Band", desc: "A heavy bracelet made by an ancient civilization about three thousand years ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Relic Copper", desc: "A copper coin used by an ancient civilization about three thousand years ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Relic Crown", desc: "A heavy crown made by an ancient civilization about three thousand years ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Relic Gold", desc: "A gold coin used by an ancient civilization about three thousand years ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Relic Silver", desc: "A silver coin used by an ancient civilization about three thousand years ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Relic Statue", desc: "A stone figurine made by an ancient civilization about three thousand years ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Relic Vase", desc: "A fragile vase made by an ancient civilization about three thousand years ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Repeat Ball", desc: "A somewhat different Poké Ball that works especially well on a Pokémon species that has been caught before.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Repel", desc: "An item that prevents any low-level wild Pokémon from jumping out at you for a while.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Reset Urge", desc: "When used, it restores any stat changes of an ally Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Resist Wing", desc: "An item for use on a Pokémon. It slightly increases the base Defense stat of a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Reveal Glass", desc: "A looking glass that reveals the truth. It’s a mysterious glass that returns a Pokémon to its original shape.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Revival Herb", desc: "A terribly bitter medicinal herb. It revives a fainted Pokémon and fully restores its max HP.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Revive", desc: "A medicine that can be used to revive a single Pokémon that has fainted. It also restores half of the Pokémon’s max HP.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Ribbon Sweet", desc: "A ribbon-shaped sweet. When a Milcery holds this, it spins around happily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rindo Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Grass-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Ring Target", desc: "An item to be held by a Pokémon. Moves that normally have no effect will land on a Pokémon holding it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rock Gem", desc: "A gem with an essence of rock. When held, it strengthens the power of a Rock-type move one time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rock Incense", desc: "An item to be held by a Pokémon. This exotic-smelling incense boosts the power of Rock-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rock Memory", desc: "A memory disc that contains Rock-type data. It changes the type of the holder if held by a certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rockium Z", desc: "It converts Z-Power into crystals that upgrade Rock-type moves to Rock-type Z-Moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rocky Helmet", desc: "An item to be held by a Pokémon. If the holder is hit, the attacker will also be damaged upon contact.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roller Skates", desc: "Attaches roller skates to the bottom of your shoes, allowing you to glide quickly around and perform tricks.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Room Service", desc: "An item to be held by a Pokémon. Lowers Speed when Trick Room takes effect.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Root Fossil", desc: "A fossil from a prehistoric Pokémon that once lived in the sea. It looks as if it could be part of a plant’s root.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rose Incense", desc: "An item to be held by a Pokémon. This exotic-smelling incense boosts the power of Grass-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roseli Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Fairy-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Bargain", desc: "One of the Rotom Powers. It reduces the prices of products at Poké Marts by half.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Boost", desc: "One of the Rotom Powers. It raises all stats of your battling Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Catch", desc: "One of the Rotom Powers. It increases the chance to catch Pokémon a lot.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Encounter", desc: "One of the Rotom Powers. It increases the chance of encountering high-level wild Pokémon a lot for a certain period of time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Exp. Points", desc: "One of the Rotom Powers. It increases the Exp. Points your Pokémon receive after battle a little.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Friendship", desc: "One of the Rotom Powers. It helps Pokémon in your party grow friendly faster.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Hatch", desc: "One of the Rotom Powers. It helps Eggs hatch faster.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto HP Restore", desc: "One of the Rotom Powers. It fully restores the HP of your battling Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto PP Restore", desc: "One of the Rotom Powers. It fully restores the PP of your battling Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Prize Money", desc: "One of the Rotom Powers. It triples the prize money you receive after battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Roto Stealth", desc: "One of the Rotom Powers. It prevents you from encountering wild Pokémon for a certain period of time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Rowap Berry", desc: "A Berry to be consumed by Pokémon. If a special attack hits the Pokémon holding it, the attacker will also be hurt.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sablenite", desc: "One of a variety of mysterious Mega Stones. Have Sableye hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sachet", desc: "A sachet filled with fragrant perfumes that are just slightly too overwhelming. Yet it’s loved by a certain Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sacred Ash", desc: "This rare ash can revive all fainted Pokémon in a party. In doing so, it also fully restores their max HP.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Safari Ball", desc: "A special Poké Ball that is used only in the Great Marsh. It is recognizable by the camouflage pattern decorating it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Safety Goggles", desc: "An item to be held by a Pokémon. These goggles protect the holder from both weather-related damage and powder.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Salac Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, its Speed stat will increase when it’s in a pinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Salad Mix", desc: "One of the many ingredients that can be used for cooking at your camp. The assortment of vegetables looks quite appealing and healthy.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Salamencite", desc: "One of a variety of mysterious Mega Stones. Have Salamence hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sassy Mint", desc: "When a Pokémon smells this mint, its Sp. Def will grow more easily, but its Speed will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sausages", desc: "One of the many ingredients that can be used for cooking at your camp. These sausages should be boiled before eating.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sceptilite", desc: "One of a variety of mysterious Mega Stones. Have Sceptile hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Scizorite", desc: "One of a variety of mysterious Mega Stones. Have Scizor hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Scope Lens", desc: "An item to be held by a Pokémon. It’s a lens for scoping out weak points. It boosts the holder’s critical-hit ratio.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sea Incense", desc: "An item to be held by a Pokémon. This incense has a curious aroma that boosts the power of Water-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Serious Mint", desc: "When a Pokémon smells this mint, all of its stats will grow at an equal rate.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shaderoot Carrot", desc: "Produce that the King of Bountiful Harvests’ beloved steed likes to eat. It grew in a gloomy field.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shalour Sable", desc: "Shalour City’s famous shortbread. It can be used once to heal all the status conditions of a Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sharp Beak", desc: "An item to be held by a Pokémon. It’s a long, sharp beak that boosts the power of Flying-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sharpedonite", desc: "One of a variety of mysterious Mega Stones. Have Sharpedo hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shed Shell", desc: "An item to be held by a Pokémon. This discarded carapace enables the holder to switch out of battle without fail.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shell Bell", desc: "An item to be held by a Pokémon. The holder restores a little HP every time it inflicts damage on others.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shiny Charm", desc: "A shiny charm said to increase the chance of finding a Shiny Pokémon in the wild.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shiny Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It shines with a dazzling light.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shoal Salt", desc: "Salt that you found inside Shoal Cave.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shoal Shell", desc: "A seashell that you found inside Shoal Cave.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shock Drive", desc: "A cassette to be held by Genesect. It changes Genesect’s Techno Blast move so it becomes Electric type.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Shuca Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Ground-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Silk Scarf", desc: "An item to be held by a Pokémon. It’s a sumptuous scarf that boosts the power of Normal-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Silver Leaf", desc: "A mysterious silver leaf. No trees with this leaf have been found yet.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Silver Nanab Berry", desc: "A Berry that calms wild Pokémon you’re trying to catch when given to them.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Silver Pinap Berry", desc: "A Berry that makes you more likely to get an item when given to Pokémon you’re trying to catch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Silver Powder", desc: "An item to be held by a Pokémon. It’s a shiny silver powder that will boost the power of Bug-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Silver Razz Berry", desc: "A Berry that makes it easier to catch Pokémon when given to them.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sitrus Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, it can restore its own HP by a small amount during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Skull Fossil", desc: "A fossil from a prehistoric Pokémon that once lived on the land. It appears as though it’s part of a head.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sky Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Flying-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Slowbronite", desc: "One of a variety of mysterious Mega Stones. Have Slowbro hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Small Bouquet", desc: "A small bouquet that was made with heart and soul for a single Trainer.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Smart Candy", desc: "A candy that is packed with energy. When given to a Pokémon, it will increase that Pokémon’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Smart Candy L", desc: "A big candy that is packed with energy. When given to a Pokémon at Lv. 30 or higher, it will increase that Pokémon’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Smart Candy XL", desc: "A huge candy that is packed with energy. When given to a Pokémon at Lv. 60 or higher, it will increase that Pokémon’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Smoke Ball", desc: "An item to be held by a Pokémon. It enables the holder to flee from any wild Pokémon encounter without fail.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Smoke-Poke Tail", desc: "One of the many ingredients that can be used for cooking at your camp. When a Slowpoke’s tail falls off, it grows back quickly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Smooth Rock", desc: "An item to be held by a Pokémon. It extends the duration of the move Sandstorm when used by the holder.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Snorlium Z", desc: "It converts Z-Power into crystals that upgrade Snorlax’s Giga Impact to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Snowball", desc: "An item to be held by a Pokémon. It boosts Attack if the holder is hit with an Ice-type attack. It can only be used once.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Soda Pop", desc: "A highly carbonated soda drink. It can be used to restore 50 HP to a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Soft Sand", desc: "An item to be held by a Pokémon. It’s a loose, silky sand that boosts the power of Ground-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Solganium Z", desc: "It converts Z-Power into crystals that upgrade Solgaleo’s Sunsteel Strike to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Soothe Bell", desc: "An item to be held by a Pokémon. The comforting chime of this bell calms the holder, making it friendly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Soul Dew", desc: "A wondrous orb to be held by either Latios or Latias. It raises the power of Psychic- and Dragon-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Spell Tag", desc: "An item to be held by a Pokémon. It’s a sinister, eerie tag that boosts the power of Ghost-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Spelon Berry", desc: "Used to make Pokéblocks that will enhance your Cuteness, this Berry is rare in other regions.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Spice Mix", desc: "One of the many ingredients that can be used for cooking at your camp. There are over fifty spices contained within this ingredient’s hot flavor.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Splash Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Water-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Spooky Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Ghost-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sport Ball", desc: "A special Poké Ball that is used during the Bug-Catching Contest.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sprinklotad", desc: "A watering can shaped like a Lotad. It helps promote the healthy growth of any Berries planted in good, soft soil.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Stable Mulch", desc: "A fertilizer for growing Berries. However, it appears to be unsuitable for the soil in the Hoenn region and has no effect.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Star Piece", desc: "A small shard of a beautiful gem that gives off a distinctly red sparkle. It can be sold at a high price to shops.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Star Sweet", desc: "A star-shaped sweet. When a Milcery holds this, it spins around happily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Stardust", desc: "Lovely red sand that flows between the fingers with a loose, silky feel. It can be sold at a low price to shops.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Starf Berry", desc: "A Berry to be consumed by Pokémon. If a Pokémon holds one, one of its stats will sharply increase when it’s in a pinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Steel Gem", desc: "A gem with an essence of steel. When held, it strengthens the power of a Steel-type move one time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Steel Memory", desc: "A memory disc that contains Steel-type data. It changes the type of the holder if held by a certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Steelium Z", desc: "It converts Z-Power into crystals that upgrade Steel-type moves to Steel-type Z-Moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Steelixite", desc: "One of a variety of mysterious Mega Stones. Have Steelix hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sticky Barb", desc: "An item to be held by a Pokémon. It damages the holder every turn and may latch on to Pokémon that touch the holder.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Stone Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Rock-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Strange Souvenir", desc: "An ornament depicting a mysterious Pokémon that has been venerated as a guardian deity for an extremely long time in the Alola region.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Strawberry Sweet", desc: "A strawberry-shaped sweet. When a Milcery holds this, it will spin around happily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Stretchy Spring", desc: "A thin small spring. It’s totally stretched out, and what it’s used for is unknown.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sun Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It burns as red as the evening sun.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Super Lure", desc: "A glass bottle of perfume that makes rare Pokémon more likely to appear. It lasts longer than a Lure.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Super Potion", desc: "A spray-type medicine for treating wounds. It can be used to restore 60 HP to a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Super Repel", desc: "An item that prevents any low-level wild Pokémon from jumping out at you for a while. It lasts longer than Repel.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Swampertite", desc: "One of a variety of mysterious Mega Stones. Have Swampert hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sweet Apple", desc: "A peculiar apple that can make a certain species of Pokémon evolve. It’s exceptionally sweet.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Sweet Heart", desc: "A piece of cloyingly sweet chocolate. It can be used to restore 20 HP to a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Swift Wing", desc: "An item for use on a Pokémon. It slightly increases the base Speed stat of a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tamato Berry", desc: "A Berry to be consumed by Pokémon. Using it on a Pokémon makes it more friendly but lowers its Speed base points.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tanga Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Bug-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tapunium Z", desc: "It converts Z-Power into crystals that upgrade the tapu’s Nature’s Madness to an exclusive Z-Move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tart Apple", desc: "A peculiar apple that can make a certain species of Pokémon evolve. It’s exceptionally tart.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Terrain Extender", desc: "An item to be held by a Pokémon. It extends the duration of the terrain caused by the holder’s move or Ability.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Thick Club", desc: "An item to be held by Cubone or Marowak. It’s a hard bone of some sort that boosts the Attack stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Throat Spray", desc: "Raises Sp. Atk when a Pokémon uses a sound-based move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Thunder Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It has a distinct thunderbolt pattern.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Timer Ball", desc: "A somewhat different Poké Ball that becomes progressively more effective at catching Pokémon the more turns that are taken in battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Timid Mint", desc: "When a Pokémon smells this mint, its Speed will grow more easily, but its Attack will grow more slowly.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tin of Beans", desc: "One of the many ingredients that can be used for cooking at your camp. When simmered, the beans suffuse a dish with their mild flavor.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tiny Mushroom", desc: "A very small and rare mushroom. It’s popular with a certain class of collectors.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM00", desc: "The target is slugged by a punch thrown with muscle-packed power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM01", desc: "The target is attacked by a kick launched with muscle-packed power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM02", desc: "Numerous coins are hurled at the target to inflict damage. Money is earned after the battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM03", desc: "The target is punched with a fiery fist. This may also leave the target with a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM04", desc: "The target is punched with an icy fist. This may also leave the target frozen.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM05", desc: "The target is punched with an electrified fist. This may also leave the target with paralysis.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM06", desc: "The user flies up into the sky and then strikes its target on the next turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM07", desc: "Sharp spikes are shot at the target in rapid succession. They hit two to five times in a row.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM08", desc: "The target is attacked with a powerful beam. The user can’t move on the next turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM09", desc: "The user charges at the target using every bit of its power. The user can’t move on the next turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM10", desc: "The user scatters curious leaves that chase the target. This attack never misses.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM100", desc: "The user tells the target a secret, and the target loses its ability to concentrate. This lowers the target’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM11", desc: "In this two-turn attack, the user gathers light, then blasts a bundled beam on the next turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM12", desc: "In this two-turn attack, the user gathers light and fills a blade with the light’s energy, attacking the target on the next turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM13", desc: "The target becomes trapped within a fierce vortex of fire that rages for four to five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM14", desc: "The user launches a weak jolt of electricity that paralyzes the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM15", desc: "The user burrows into the ground, then attacks on the next turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM16", desc: "An earsplitting screech harshly lowers the target’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM17", desc: "A wondrous wall of light is put up to reduce damage from special attacks for five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM18", desc: "A wondrous wall of light is put up to reduce damage from physical attacks for five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM19", desc: "The user creates a protective field that prevents status conditions for five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM20", desc: "The user attacks everything around it by causing an explosion. The user faints upon using this move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM21", desc: "The user goes to sleep for two turns. This fully restores the user’s HP and heals any status conditions.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM22", desc: "Large boulders are hurled at opposing Pokémon to inflict damage. This may also make the opposing Pokémon flinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM23", desc: "The user attacks and steals the target’s held item simultaneously. The user can’t steal anything if it already holds an item.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM24", desc: "This attack can be used only if the user is asleep. The harsh noise may also make the target flinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM25", desc: "This move enables the user to protect itself from all attacks. Its chance of failing rises if it is used in succession.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM26", desc: "The user frightens the target with a scary face to harshly lower its Speed stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM27", desc: "The user attacks with a gust of chilled air. This also lowers opposing Pokémon’s Speed stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM28", desc: "A nutrient-draining attack. The user’s HP is restored by half the damage taken by the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM29", desc: "The user gazes at the target rather charmingly, making it less wary. This harshly lowers the target’s Attack stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM30", desc: "The target is hit with wings of steel. This may also raise the user’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM31", desc: "If it is the opposite gender of the user, the target becomes infatuated and less likely to attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM32", desc: "A five-turn sandstorm is summoned to hurt all combatants except Rock, Ground, and Steel types. It raises the Sp. Def stat of Rock types.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM33", desc: "The user summons a heavy rain that falls for five turns, powering up Water-type moves. It lowers the power of Fire-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM34", desc: "The user intensifies the sun for five turns, powering up Fire-type moves. It lowers the power of Water-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM35", desc: "The user summons a hailstorm lasting five turns. It damages all Pokémon except Ice types.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM36", desc: "The user traps the target in a violent swirling whirlpool for four to five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM37", desc: "The user gets all party Pokémon to attack the target. The more party Pokémon, the greater the number of attacks.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM38", desc: "The user shoots a sinister flame at the target to inflict a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM39", desc: "This attack move doubles its power if the user is poisoned, burned, or paralyzed.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM40", desc: "Star-shaped rays are shot at opposing Pokémon. This attack never misses.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM41", desc: "The user assists an ally by boosting the power of that ally’s attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM42", desc: "This attack move’s power is doubled if the user has been hurt by the opponent in the same turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM43", desc: "The user attacks with a swift chop. It can also break barriers, such as Light Screen and Reflect.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM44", desc: "If opposing Pokémon know any move also known by the user, they are prevented from using it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM45", desc: "Diving on the first turn, the user floats up and attacks on the next turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM46", desc: "This attack move varies in power and type depending on the weather.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM47", desc: "The user feigns crying to fluster the target, harshly lowering its Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM48", desc: "Boulders are hurled at the target. This also lowers the target’s Speed stat by preventing its movement.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM49", desc: "The user traps the target inside a harshly raging sandstorm for four to five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM50", desc: "The user forcefully shoots seeds at the target two to five times in a row.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM51", desc: "The user launches sharp icicles at the target two to five times in a row.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM52", desc: "The user bounces up high, then drops on the target on the second turn. This may also leave the target with paralysis.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM53", desc: "The user attacks by hurling a blob of mud at the target. This also lowers the target’s Speed stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM54", desc: "The user hurls hard rocks at the target. Two to five rocks are launched in a row.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM55", desc: "If the target’s HP is half or less, this attack will hit with double the power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM56", desc: "After making its attack, the user rushes back to switch places with a party Pokémon in waiting.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM57", desc: "The user stores power, then attacks. If the user moves after the target, this attack’s power will be doubled.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM58", desc: "If the target has already taken some damage in the same turn, this attack’s power is doubled.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM59", desc: "The user flings its held item at the target to attack. This move’s power and effects depend on the item.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM60", desc: "The user employs its psychic power to switch changes to its Attack and Sp. Atk stats with the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM61", desc: "The user employs its psychic power to switch changes to its Defense and Sp. Def stats with the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM62", desc: "The user exchanges Speed stats with the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM63", desc: "An energy-draining punch. The user’s HP is restored by half the damage taken by the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM64", desc: "The power of this attack move is doubled if the user has been hurt by the target in the same turn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM65", desc: "The user slashes with a sharp claw made from shadows. Critical hits land more easily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM66", desc: "The user bites with electrified fangs. This may also make the target flinch or leave it with paralysis.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM67", desc: "The user bites with cold-infused fangs. This may also make the target flinch or leave it frozen.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM68", desc: "The user bites with flame-cloaked fangs. This may also make the target flinch or leave it with a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM69", desc: "The user tears at the target with blades formed by psychic power. Critical hits land more easily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM70", desc: "The user creates a bizarre area in which slower Pokémon get to move first for five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM71", desc: "The user creates a bizarre area in which Pokémon’s Defense and Sp. Def stats are swapped for five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM72", desc: "The user creates a bizarre area in which Pokémon’s held items lose their effects for five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM73", desc: "A slashing attack with a poisonous blade that may also poison the target. Critical hits land more easily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM74", desc: "The user drenches the target in a special poisonous liquid. This move’s power is doubled if the target is poisoned.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM75", desc: "The user makes a swift attack on the target’s legs, which lowers the target’s Speed stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM76", desc: "The user attacks the target with a song. Others can join in the Round to increase the power of the attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM77", desc: "This relentless attack does massive damage to a target affected by status conditions.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM78", desc: "The user nimbly strikes the target. If the user is not holding an item, this attack inflicts massive damage.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM79", desc: "The user gets revenge for a fainted ally. If an ally fainted in the previous turn, this move’s power is increased.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM80", desc: "After making its attack, the user rushes back to switch places with a party Pokémon in waiting.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM81", desc: "The user strikes everything around it by stomping down on the ground. This lowers the Speed stats of those hit.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM82", desc: "The user attacks and captures opposing Pokémon using an electric net. This lowers their Speed stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM83", desc: "The user cuts its target with sharp shells. This may also lower the target’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM84", desc: "The user attacks by striking the target with its hard tail. It hits the target two to five times in a row.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM85", desc: "The user yells as if it’s ranting about something, which lowers the Sp. Atk stats of opposing Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM86", desc: "The user vanishes somewhere, then strikes the target on the next turn. This move hits even if the target protects itself.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM87", desc: "The user steals the target’s HP with a kiss. The user’s HP is restored by over half of the damage taken by the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM88", desc: "The user turns the ground to grass for five turns. This restores the HP of Pokémon on the ground a little every turn and powers up Grass-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM89", desc: "This protects Pokémon on the ground from status conditions and halves damage from Dragon-type moves for five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM90", desc: "The user electrifies the ground for five turns, powering up Electric-type moves. Pokémon on the ground no longer fall asleep.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM91", desc: "This protects Pokémon on the ground from priority moves and powers up Psychic-type moves for five turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM92", desc: "The user attacks by breathing a special, hot fire. This also lowers the target’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM93", desc: "The user’s body generates an eerie impulse. Exposing the target to it harshly lowers the target’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM94", desc: "A restrained attack that prevents the target from fainting. The target is left with at least 1 HP.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM95", desc: "The user attacks with a blade of air that slices even the sky. This may also make the target flinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM96", desc: "The user stabs the target with a sharp horn. This attack never misses.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM97", desc: "The user swings its body around violently to inflict damage on everything in its vicinity.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM98", desc: "Driven by frustration, the user attacks the target. If the user’s previous move has failed, the power of this move doubles.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TM99", desc: "The user swings its tough tail wildly and attacks opposing Pokémon. This also lowers their Attack stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TMV Pass", desc: "A commuter pass that allows the holder to ride the TMV between Lumiose City and Kiloude City at any time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tough Candy", desc: "A candy that is packed with energy. When given to a Pokémon, it will increase that Pokémon’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tough Candy L", desc: "A big candy that is packed with energy. When given to a Pokémon at Lv. 30 or higher, it will increase that Pokémon’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tough Candy XL", desc: "A huge candy that is packed with energy. When given to a Pokémon at Lv. 60 or higher, it will increase that Pokémon’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Toxic Orb", desc: "An item to be held by a Pokémon. It’s a bizarre orb that will badly poison the holder during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Toxic Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Poison-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR00", desc: "A frenetic dance to uplift the fighting spirit. This sharply raises the user’s Attack stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR01", desc: "The user drops onto the target with its full body weight. This may also leave the target with paralysis.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR02", desc: "The target is scorched with an intense blast of fire. This may also leave the target with a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR03", desc: "The target is blasted by a huge volume of water launched under great pressure.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR04", desc: "The user attacks everything around it by swamping its surroundings with a giant wave.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR05", desc: "The target is struck with an icy-cold beam of energy. This may also leave the target frozen.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR06", desc: "A howling blizzard is summoned to strike opposing Pokémon. This may also leave the opposing Pokémon frozen.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR07", desc: "A powerful low kick that makes the target fall over. The heavier the target, the greater the move’s power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR08", desc: "A strong electric blast crashes down on the target. This may also leave the target with paralysis.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR09", desc: "A wicked thunderbolt is dropped on the target to inflict damage. This may also leave the target with paralysis.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR10", desc: "The user sets off an earthquake that strikes every Pokémon around it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR11", desc: "The target is hit by a strong telekinetic force. This may also lower the target’s Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR12", desc: "The user relaxes and lightens its body to move faster. This sharply raises the Speed stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR13", desc: "The user takes a deep breath and focuses so that critical hits land more easily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR14", desc: "The user waggles a finger and stimulates its brain into randomly using nearly any move.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR15", desc: "The target is attacked with an intense blast of all-consuming fire. This may also leave the target with a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR16", desc: "The user charges at the target and may make it flinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR17", desc: "The user temporarily empties its mind to forget its concerns. This sharply raises the user’s Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR18", desc: "The user drains the target’s blood. The user’s HP is restored by half the damage taken by the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR19", desc: "The user strikes with a simultaneous three-beam attack. This may also burn, freeze, or paralyze the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR20", desc: "The user creates a substitute for itself using some of its HP. The substitute serves as the user’s decoy.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR21", desc: "An all-out attack that becomes more powerful the less HP the user has.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR22", desc: "Unsanitary sludge is hurled at the target. This may also poison the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR23", desc: "The user lays a trap of spikes at the opposing team’s feet. The trap hurts Pokémon that switch into battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR24", desc: "The user rampages and attacks for two to three turns. The user then becomes confused.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR25", desc: "The user materializes an odd psychic wave to attack the target. This attack does physical damage.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR26", desc: "The user endures any attack with at least 1 HP. Its chance of failing rises if it is used in succession.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR27", desc: "While it is asleep, the user randomly uses one of the moves it knows.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR28", desc: "Using its tough and impressive horn, the user rams into the target with no letup.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR29", desc: "The user switches places with a party Pokémon in waiting and passes along any stat changes.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR30", desc: "The user compels the target to keep using the move it encored for three turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR31", desc: "The target is slammed with a steel-hard tail. This may also lower the target’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR32", desc: "The user crunches up the target with sharp fangs. This may also lower the target’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR33", desc: "The user hurls a shadowy blob at the target. This may also lower the target’s Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR34", desc: "Two turns after this move is used, a hunk of psychic energy attacks the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR35", desc: "The user attacks in an uproar for three turns. During that time, no Pokémon can fall asleep.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR36", desc: "The user attacks by exhaling hot breath on opposing Pokémon. This may also leave those Pokémon with a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR37", desc: "The target is taunted into a rage that allows it to use only attack moves for three turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR38", desc: "The user catches the target off guard and swaps its held item with its own.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR39", desc: "The user attacks the target with great power. However, this also lowers the user’s Attack and Defense stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR40", desc: "The user employs its psychic power to exchange Abilities with the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR41", desc: "The user launches a kick that lands a critical hit more easily. This may also leave the target with a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR42", desc: "The user lets loose a horribly echoing shout with the power to inflict damage.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR43", desc: "The user attacks the target at full power. The attack’s recoil harshly lowers the user’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR44", desc: "The user absorbs a mystical power from space to raise its Defense and Sp. Def stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR45", desc: "The user attacks by shooting muddy water at opposing Pokémon. This may also lower their accuracy.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR46", desc: "The user hardens its body’s surface like iron, sharply raising its Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR47", desc: "The user slashes the target with huge sharp claws.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR48", desc: "The user tenses its muscles to bulk up its body, raising both its Attack and Defense stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR49", desc: "The user quietly focuses its mind and calms its spirit to raise its Sp. Atk and Sp. Def stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR50", desc: "The user handles a sharp leaf like a sword and attacks by cutting its target. Critical hits land more easily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR51", desc: "The user vigorously performs a mystic, powerful dance that raises its Attack and Speed stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR52", desc: "The user tackles the target with a high-speed spin. The slower the user compared to the target, the greater the move’s power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR53", desc: "The user fights the target up close without guarding itself. This also lowers the user’s Defense and Sp. Def stats.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR54", desc: "The user lays a trap of poison spikes at the feet of the opposing team. The spikes will poison opposing Pokémon that switch into battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR55", desc: "The user cloaks itself in fire and charges the target. This also damages the user quite a lot. This attack may leave the target with a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR56", desc: "The user lets loose a blast of aura power from deep within its body at the target. This attack never misses.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR57", desc: "The target is stabbed with a tentacle, arm, or the like steeped in poison. This may also poison the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR58", desc: "The user releases a horrible aura imbued with dark thoughts. This may also make the target flinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR59", desc: "The user slams a barrage of hard-shelled seeds down on the target from above.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR60", desc: "The user slashes at the target by crossing its scythes or claws as if they were a pair of scissors.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR61", desc: "The user generates a damaging sound wave by vibration. This may also lower the target’s Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR62", desc: "The target is attacked with a shock wave generated by the user’s gaping mouth.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR63", desc: "The user attacks with a ray of light that sparkles as if it were made of gemstones.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR64", desc: "The user heightens its mental focus and unleashes its power. This may also lower the target’s Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR65", desc: "The user draws power from nature and fires it at the target. This may also lower the target’s Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR66", desc: "The user tucks in its wings and charges from a low altitude. This also damages the user quite a lot.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR67", desc: "The user makes the ground under the target erupt with power. This may also lower the target’s Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR68", desc: "The user stimulates its brain by thinking bad thoughts. This sharply raises the user’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR69", desc: "The user focuses its willpower to its head and attacks the target. This may also make the target flinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR70", desc: "The user gathers all its light energy and releases it all at once. This may also lower the target’s Sp. Def stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR71", desc: "The user whips up a storm of leaves around the target. The attack’s recoil harshly lowers the user’s Sp. Atk stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR72", desc: "The user violently whirls its vines, tentacles, or the like to harshly lash the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR73", desc: "The user shoots filthy garbage at the target to attack. This may also poison the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR74", desc: "The user slams the target with its steel-hard head. This may also make the target flinch.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR75", desc: "The user stabs the target from below with sharpened stones. Critical hits land more easily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR76", desc: "The user lays a trap of levitating stones around the opposing team. The trap hurts opposing Pokémon that switch into battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR77", desc: "The user snares the target with grass and trips it. The heavier the target, the greater the move’s power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR78", desc: "The user strikes everything around it by swamping the area with a giant sludge wave. This may also poison those hit.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR79", desc: "The user slams into the target with its heavy body. The more the user outweighs the target, the greater the move’s power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR80", desc: "The user hurls an electric orb at the target. The faster the user is than the target, the greater the move’s power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR81", desc: "The user turns the target’s power against it. The higher the target’s Attack stat, the greater the damage it deals.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR82", desc: "The user attacks the target with stored power. The more the user’s stats are raised, the greater the move’s power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR83", desc: "The user teleports using a strange power and switches places with one of its allies.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR84", desc: "The user shoots boiling hot water at its target. This may also leave the target with a burn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR85", desc: "The user is roused, and its Attack and Sp. Atk stats increase.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR86", desc: "The user shrouds itself in electricity and smashes into its target. This also damages the user a little.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR87", desc: "The user crashes into its target while rotating its body like a drill. Critical hits land more easily.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR88", desc: "The user slams its target with its flame-covered body. The more the user outweighs the target, the greater the move’s power.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR89", desc: "The user attacks by wrapping its opponent in a fierce wind that flies up into the sky. This may also confuse the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR90", desc: "The user plays rough with the target and attacks it. This may also lower the target’s Attack stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR91", desc: "Opposing Pokémon are drenched in an odd poisonous liquid. This lowers the Attack, Sp. Atk, and Speed stats of a poisoned target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR92", desc: "The user damages opposing Pokémon by emitting a powerful flash.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR93", desc: "The user swings both arms and hits the target. The target’s stat changes don’t affect this attack’s damage.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR94", desc: "The user fiercely attacks the target using its entire body.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR95", desc: "The user attacks the target’s throat, and the resultant suffering prevents the target from using moves that emit sound for two turns.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR96", desc: "The user attacks the enemy with a pollen puff that explodes. If the target is an ally, it gives the ally a pollen puff that restores its HP instead.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR97", desc: "The user bites the target with its psychic capabilities. This can also destroy Light Screen and Reflect.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR98", desc: "The user slams into the target using a full-force blast of water. This may also lower the target’s Defense stat.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "TR99", desc: "The user attacks by slamming its body into the target. The higher the user’s Defense, the more damage it can inflict on the target.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tropical Shell", desc: "A beautiful white shell that may have drifted from a sea in a warm region.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Twisted Spoon", desc: "An item to be held by a Pokémon. This spoon is imbued with telekinetic power and boosts Psychic-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Tyranitarite", desc: "One of a variety of mysterious Mega Stones. Have Tyranitar hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Ultra Ball", desc: "An ultra-high-performance Poké Ball that provides a higher success rate for catching Pokémon than a Great Ball.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Ultranecrozium Z", desc: "It’s a crystal that turns Necrozma fused with Solgaleo or Lunala into a new form.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Upgrade", desc: "A transparent device somehow filled with all sorts of data. It was produced by Silph Co.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Utility Umbrella", desc: "An item to be held by a Pokémon. This sturdy umbrella protects the holder from the effects of weather.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Venusaurite", desc: "One of a variety of mysterious Mega Stones. Have Venusaur hold it, and this stone will enable it to Mega Evolve during battle.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Wacan Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Electric-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Water Gem", desc: "A gem with an essence of water. When held, it strengthens the power of a Water-type move one time.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Water Memory", desc: "A memory disc that contains Water-type data. It changes the type of the holder if held by a certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Water Stone", desc: "A peculiar stone that can make certain species of Pokémon evolve. It is the blue of a pool of clear water.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Waterium Z", desc: "It converts Z-Power into crystals that upgrade Water-type moves to Water-type Z-Moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Watmel Berry", desc: "Used to make Pokéblocks that will enhance your Cleverness, this Berry is rare in other regions.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Wave Incense", desc: "An item to be held by a Pokémon. This incense has a curious aroma that boosts the power of Water-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Weakness Policy", desc: "An item to be held by a Pokémon. Attack and Sp. Atk sharply increase if the holder is hit with a move it’s weak to.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Wepear Berry", desc: "Used to make Pokéblocks that will enhance your Cleverness. Its green flesh is bitter when eaten.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Whipped Dream", desc: "A soft and sweet treat made of fluffy, puffy, whipped, and whirled cream. It’s loved by a certain Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "White Apricorn", desc: "A white Apricorn. It doesn’t smell like anything.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "White Flute", desc: "A flute made from white glass. It makes it easier to encounter weak Pokémon in the place you use it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "White Herb", desc: "An item to be held by a Pokémon. It will restore any lowered stat in battle. It can be used only once.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Wide Lens", desc: "An item to be held by a Pokémon. It’s a magnifying lens that slightly boosts the accuracy of moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Wiki Berry", desc: "If held by a Pokémon, it restores the user’s HP in a pinch, but it will cause confusion if the user hates the taste.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Wise Glasses", desc: "An item to be held by a Pokémon. This thick pair of glasses slightly boosts the power of special moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Wishing Piece", desc: "Throw one into a Pokémon Den to attract a wild Dynamax Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Accuracy", desc: "An item that sharply boosts the accuracy of a Pokémon during a battle. It wears off once the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Accuracy 2", desc: "It sharply raises the accuracy of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Accuracy 3", desc: "It drastically raises the accuracy of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Accuracy 6", desc: "It raises the accuracy of a Pokémon in battle immensely. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Attack", desc: "An item that sharply boosts the Attack stat of a Pokémon during a battle. It wears off once the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Attack 2", desc: "It sharply raises the Attack stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Attack 3", desc: "It drastically raises the Attack stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Attack 6", desc: "It raises the Attack stat of a Pokémon in battle immensely. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Defense", desc: "An item that sharply boosts the Defense stat of a Pokémon during a battle. It wears off once the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Defense 2", desc: "It sharply raises the Defense stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Defense 3", desc: "It drastically raises the Defense stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Defense 6", desc: "It raises the Defense stat of a Pokémon in battle immensely. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Sp. Atk", desc: "An item that sharply boosts the Sp. Atk stat of a Pokémon during a battle. It wears off once the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Sp. Atk 2", desc: "It sharply raises the Sp. Atk stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Sp. Atk 3", desc: "It drastically raises the Sp. Atk stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Sp. Atk 6", desc: "It raises the Sp. Atk stat of a Pokémon in battle immensely. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Sp. Def", desc: "An item that sharply boosts the Sp. Def stat of a Pokémon during a battle. It wears off once the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Sp. Def 2", desc: "It sharply raises the Sp. Def stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Sp. Def 3", desc: "It drastically raises the Sp. Def stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Sp. Def 6", desc: "It raises the Sp. Def stat of a Pokémon in battle immensely. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Speed", desc: "An item that sharply boosts the Speed stat of a Pokémon during a battle. It wears off once the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Speed 2", desc: "It sharply raises the Speed stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Speed 3", desc: "It drastically raises the Speed stat of a Pokémon in battle. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "X Speed 6", desc: "It raises the Speed stat of a Pokémon in battle immensely. It wears off if the Pokémon is withdrawn.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Yache Berry", desc: "If held by a Pokémon, this Berry will lessen the damage taken from one supereffective Ice-type attack.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Yellow Apricorn", desc: "A yellow Apricorn. It has an invigorating scent.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Yellow Flute", desc: "A flute made from yellow glass. It snaps Pokémon out of confusion.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Yellow Nectar", desc: "A flower nectar obtained at Melemele Meadow. It changes the form of certain species of Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Yellow Scarf", desc: "An item to be held by a Pokémon. During a contest, it raises the Tough aspect of the Pokémon holding it.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Yellow Shard", desc: "A small yellow shard. It appears to be a fragment of some sort of implement made long ago.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Zap Plate", desc: "An item to be held by a Pokémon. It’s a stone tablet that boosts the power of Electric-type moves.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Zinc", desc: "A nutritious drink for Pokémon. When consumed, it raises the Sp. Def base points of a single Pokémon.", evoEffects: [], category: .battle, moveName: nil),

        Item(name: "Zoom Lens", desc: "An item to be held by a Pokémon. If the holder moves after its target moves, its accuracy will be boosted.", evoEffects: [], category: .battle, moveName: nil)
        
    ]
    
    // MARK: - Functions
    static func itemLookup(_ name: String) -> Item? {
        for eachItem in Item.itemList {
            if eachItem.name == name {
                return eachItem
            }
        }
        return nil
    }
    
}

enum ItemType: String, Codable {
    
    case battle // Battle items, such as X items and Roto items
    case enhancer // Items used once to enhance or change a Pokémon, such as an Ability Capsule
    case megaEvolution // Items relating to mega evolution, that is, Mega Stones
    case heldItems // Give an effect in battle when a Pokémon holds the item (excluding Mega Stones)
    case zcrystals // Z-Crystals found and used in Alola
    case evolution // An item that allows a Pokémon to evolve
    case keyItems // Items classified in game as "key"
    case berriesAndApricorns // Berry items and apricorn items
    case medicine // Healing/restoration items like Potions
    case fossils // Fossil items
    case treasures // Treasures like pearls, ore, etc.
    case ingredients // Items that belong to this pocket in Sword/Shield
    case pokeBalls // Poke Ball items
    case machines // HMs, TMs, and TRs
    
}
