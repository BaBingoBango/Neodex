//
//  Ability.swift
//  Neodex
//
//  Created by Ethan Marshall on 12/29/20.
//

import Foundation

struct Ability: Codable {
    
    // Variables
    var name: String
    var detail: String
    
    static let abilityList: [Ability] = [
    
        Ability(name: "Overgrow", detail: "Powers up Grass-type moves by 50% when the Pokémon's HP is below one-third its maximum."),
        
        Ability(name: "Blaze", detail: "Powers up Fire-type moves when the Pokémon’s HP is below one-third its maximum."),
        
        Ability(name: "Solar Power", detail: "Boosts the Pokémon's Sp. Atk stat by 50% in harsh sunlight, but it loses one-eighth of its HP every turn."),
        
        Ability(name: "Torrent", detail: "Powers up Water-type moves by 50% when the Pokémon’s HP is below one-third its maximum."),
        
        Ability(name: "Rain Dish", detail: "When in rain, the Pokémon regains one-sixteenth of its HP every turn."),
        
        Ability(name: "Tinted Lens", detail: "The Pokémon can use “not very effective” moves to deal regular damage."),
        
        Ability(name: "Swarm", detail: "Powers up Bug-type moves by 50% when the Pokémon's HP is below one-third its maximum. Outside of battle, if the Pokémon is leading the party, wild Pokémon are twice as likely to appear."),
        
        Ability(name: "Adaptability", detail: "Powers up moves of the same type as the Pokémon by 2x instead of the normal 1.5x."),
        
        Ability(name: "Big Pecks", detail: "Protects the Pokémon from Defense-lowering effects."),
        
        Ability(name: "Gluttony", detail: "Makes the Pokémon eat a held Berry when its HP drops to half or less, which is sooner than usual."),
        
        Ability(name: "Static", detail: "The Pokémon is charged with static electricity, so there is a 30% chance contact with it will cause paralysis. Outside of battle, if the Pokémon is leading the party, wild Pokémon are 50% more likely to be Electric type."),
        
        Ability(name: "Sheer Force", detail: "Removes additional effects to increase the power of moves when attacking by 30%."),
        
        Ability(name: "Magic Guard", detail: "The Pokémon only takes damage from attacks."),
        
        Ability(name: "Unaware", detail: "When attacking, the Pokémon ignores the target Pokémon’s stat changes."),
        
        // Alphabetical section
        
        Ability(name: "Aerilate", detail: "Normal-type moves the Pokémon knows become Flying-type moves."),
        
        Ability(name: "Aftermath", detail: "If an attacker KOs the Pokémon, the attacker will lose 25% of their maximum HP."),
        
        Ability(name: "Air Lock", detail: "All special effects brought on by weather conditions are negated."),
        
        Ability(name: "Analytic", detail: "If the Pokémon moves last, the power of its move is increased by 30%."),
        
        Ability(name: "Anger Point", detail: "Upon taking a critical hit, the Pokémon's attack is boosted to its maximum level (6 stages)."),
        
        Ability(name: "Anticipation", detail: "The Pokémon senses foes' dangerous moves when it switches in; it will shudder if an opponent has a move that is super-effective against the Pokémon or knows a one-hit KO move."),
        
        Ability(name: "Arena Trap", detail: "Aside from Flying-types or Pokémon who are not touching the ground, opponents cannot flee or switch out."),
        
        Ability(name: "Aroma Veil", detail: "The Pokémon and its allies cannot be hit with any moves that limit their move choices."),
        
        Ability(name: "As One", detail: "This Ability combines the effects of both Calyrex’s Unnerve Ability and Glastrier’s/Spectrier’s Chilling Neigh/Grim Neigh Ability."),
        
        Ability(name: "Aura Break", detail: "The effects of “Aura” Abilities are reversed to lower the power of affected moves by 25%."),
        
        Ability(name: "Bad Dreams", detail: "All sleeping opponents will lose 1/8 of their maximum HP at the end of each turn."),
        
        Ability(name: "Ball Fetch", detail: "If the Pokémon is not holding an item, it will fetch the Poké Ball from the first failed throw of the battle."),
        
        Ability(name: "Battery", detail: "The power of this Pokémon's allies' special moves is increased by 30%."),
        
        Ability(name: "Battle Armor", detail: "Hard armor protects the Pokémon from critical hits."),
        
        Ability(name: "Battle Bond", detail: "Defeating an opposing Pokémon strengthens the Pokémon’s bond with its Trainer, and it becomes Ash-Greninja. Water Shuriken's power increases from 15 and 20 and will always hit three times."),
        
        Ability(name: "Beast Boost", detail: "The Pokémon boosts its most proficient stat by one stage each time it knocks out a Pokémon."),
        
        Ability(name: "Berserk", detail: "Boosts the Pokémon’s Sp. Atk stat by one stage when it takes a hit that causes its HP to become half or less."),
        
        Ability(name: "Bulletproof", detail: "Protects the Pokémon from \"ball and bomb\" moves.\n\nThese are Acid Spray, Aura Sphere, Barrage, Beak Blast, Bullet Seed, Egg Bomb, Electro Ball, Energy Ball, Focus Blast, Gyro Ball, Ice Ball, Magnet Bomb, Mist Ball, Mud Bomb, Octazooka, Pollen Puff, Rock Blast, Rock Wrecker, Searing Shot, Seed Bomb, Shadow Ball, Sludge Bomb, Weather Ball, and Zap Cannon."),
        
        Ability(name: "Cheek Pouch", detail: "When the Pokémon consumes a Berry, 33% of its maximum HP is restored along with the Berry's normal effect."),

        Ability(name: "Chilling Neigh", detail: "When the Pokémon knocks out a target, it utters a chilling neigh, which boosts its Attack stat by one stage."),

        Ability(name: "Chlorophyll", detail: "Doubles the Pokémon’s Speed stat in harsh sunlight."),

        Ability(name: "Clear Body", detail: "Prevents other Pokémon’s moves or Abilities from lowering the Pokémon’s stats."),

        Ability(name: "Cloud Nine", detail: "When the Pokémon is in battle, all effects of the weather are eliminated."),

        Ability(name: "Color Change", detail: "The Pokémon’s type becomes the type of the move used on it."),

        Ability(name: "Comatose", detail: "The Pokémon always acts like it is asleep, but does not have the sleep status condition. It can attack without \"waking up\", and cannot be poisoned, paralyzed, burned, frozen, or put to sleep in the traditional sense."),

        Ability(name: "Competitive", detail: "Boosts the Sp. Atk stat by two stages when one of the Pokémon's stats is lowered."),

        Ability(name: "Compound Eyes", detail: "The Pokémon’s compound eyes boost its accuracy by 30%. Outside of battle, if the Pokémon is first in the party, wild Pokémon that have the chance to be holding items have that chance increased."),

        Ability(name: "Contrary", detail: "Makes stat changes have an opposite effect on the Pokémon."),

        Ability(name: "Corrosion", detail: "The Pokémon can poison the target even if it’s a Steel or Poison type."),

        Ability(name: "Cotton Down", detail: "When the Pokémon is hit by an attack, it scatters cotton fluff around and lowers the Speed stat of all Pokémon except itself by one stage."),

        Ability(name: "Curious Medicine", detail: "When the Pokémon enters battle, stat changes of ally Pokémon are reset."),

        Ability(name: "Cursed Body", detail: "When a damaging move is used on the Pokémon, there is a 30% chance the move will be disabled for four turns."),

        Ability(name: "Cute Charm", detail: "When a move that makes contact is used on the Pokémon, there is a 30% chance that the attacker will become infatuated, as long as the attacker is not of the same gender, is not genderless, and does not have the ability Oblivious."),

        Ability(name: "Damp", detail: "Prevents the use of explosive moves on all Pokémon on the field, such as Self-Destruct and Explosion, by dampening its surroundings. The Pokémon protects itself only from the effects of Aftermath."),

        Ability(name: "Dancer", detail: "When another Pokémon uses a dance move, it can use a dance move following it regardless of its Speed. It will still use its originally selected move."),

        Ability(name: "Dark Aura", detail: "Powers up all Pokémon’s Dark-type moves by 33%."),

        Ability(name: "Dauntless Shield", detail: "Boosts the Pokémon’s Defense stat by one stage when the Pokémon enters a battle."),

        Ability(name: "Dazzling", detail: "Surprises the opposing Pokémon, making itself immune to positive-priority moves."),

        Ability(name: "Defeatist", detail: "Halves the Pokémon’s Attack and Sp. Atk stats when its HP becomes half or less."),

        Ability(name: "Defiant", detail: "Boosts the Pokémon’s Attack stat by two stages when its stats are lowered."),

        Ability(name: "Delta Stream", detail: "The Pokémon changes the weather to strong winds as long as it is in battle, eliminating all of the Flying type’s weaknesses. The strong winds cannnot be replaced by other weather conditions."),

        Ability(name: "Desolate Land", detail: "The Pokémon changes the weather to extremely harsh sunlight, nullifing Water-type attacks. Extremely harsh sunlight is identical to standard harsh sunlight, save for the fact that it lasts as long as the ability-bearer remains in battle, cannot be replaced by other weather conditions, and completely negates Water-type attacks."),

        Ability(name: "Disguise", detail: "Once per battle, the shroud that covers the Pokémon can protect it from an attack."),

        Ability(name: "Download", detail: "Compares an opposing Pokémon’s Defense and Sp. Def stats before raising its own Attack or Sp. Atk stat by one stage—whichever will be more effective."),

        Ability(name: "Dragon's Maw", detail: "Powers up the Pokémon's Dragon-type moves by 50%."),

        Ability(name: "Drizzle", detail: "The Pokémon makes it rain when it enters a battle. The rain lasts for five turns."),

        Ability(name: "Drought", detail: "Turns the sunlight harsh when the Pokémon enters a battle. The efefct lasts for gfive turns."),

        Ability(name: "Dry Skin", detail: "Restores HP in rain by 1/8 of the Pokémon's maximum HP each turn. When hit by Water-type moves, restores 1/4 of the Pokémon's maximum HP. Reduces HP in harsh sunlight by 1/8 of the Pokémon's maximum HP each turn. Increases the damage received from Fire-type moves by 25%."),

        Ability(name: "Early Bird", detail: "The Pokémon awakens from sleep twice as fast as other Pokémon."),

        Ability(name: "Effect Spore", detail: "When a Pokémon with this Ability is hit by a move that makes contact, there is a 9% chance of poison, 10% chance of paralysis, and 11% chance of sleep (to be inflicted on the attacker)."),

        Ability(name: "Electric Surge", detail: "Turns the ground into Electric Terrain when the Pokémon enters a battle. The terrain prevents Pokémon on the ground from falling asleep and increases the power of Electric-type moves by 30%. The terrain lasts for five turns."),

        Ability(name: "Emergency Exit", detail: "The Pokémon, sensing danger, switches out when its HP becomes half or less."),

        Ability(name: "Fairy Aura", detail: "Powers up each Pokémon’s Fairy-type moves by 33%."),

        Ability(name: "Filter", detail: "Reduces the power of super-effective attacks taken by 25%."),

        Ability(name: "Flame Body", detail: "Contact with the Pokémon has a 30% chance to burn the attacker."),

        Ability(name: "Flare Boost", detail: "Powers up special attacks by 50% when the Pokémon is burned."),

        Ability(name: "Flash Fire", detail: "Powers up the Pokémon’s Fire-type moves by 50% if it’s hit by one. The Pokémon is immune to damage from Fire-type moves. The power increase can occur only once."),

        Ability(name: "Flower Gift", detail: "Boosts the Attack and Sp. Def stats of itself and allies by 50% while in harsh sunlight."),

        Ability(name: "Flower Veil", detail: "Ally Grass-type Pokémon are protected from status conditions and the lowering of their stats."),

        Ability(name: "Fluffy", detail: "Halves the damage taken from moves that make direct contact, but doubles that of Fire-type moves."),

        Ability(name: "Forecast", detail: "The Pokémon transforms with the weather to change its type to Water, Fire, or Ice."),

        Ability(name: "Forewarn", detail: "When it enters a battle, the Pokémon can tell one of the moves an opposing Pokémon has. The move identified will be the highest power move known by the opponent(s)."),

        Ability(name: "Friend Guard", detail: "Aside from the few moves that do direct damage (such as one-hit KO moves), this ability reduces damage recieved by allies by 25%."),

        Ability(name: "Frisk", detail: "When it enters a battle, the Pokémon can check an opposing Pokémon’s held item."),

        Ability(name: "Full Metal Body", detail: "Prevents other Pokémon’s moves or Abilities from lowering the Pokémon’s stats."),

        Ability(name: "Fur Coat", detail: "Halves the damage from physical moves."),

        Ability(name: "Gale Wings", detail: "Gives +1 priority to Flying-type moves when the Pokémon’s HP is full."),

        Ability(name: "Galvanize", detail: "Normal-type moves become Electric-type moves. The power of those moves is boosted by 20%."),

        Ability(name: "Gooey", detail: "Contact with the Pokémon lowers the attacker’s Speed stat by one stage."),

        Ability(name: "Gorilla Tactics", detail: "Boosts the Pokémon’s Attack stat by 50% but only allows the use of the first selected move."),

        Ability(name: "Grass Pelt", detail: "Boosts the Pokémon’s Defense stat by 50% while on Grassy Terrain."),

        Ability(name: "Grassy Surge", detail: "Turns the ground into Grassy Terrain when the Pokémon enters a battle. For grounded Pokémon, the power of Grass-type moves is increased by 30% and each turn, all such Pokémon see their HP restored by 1/16 of its maximum. The terrain lasts for five turns."),

        Ability(name: "Grim Neigh", detail: "When the Pokémon knocks out a target, it utters a terrifying neigh, which boosts its Sp. Atk stat by one stage."),

        Ability(name: "Gulp Missile", detail: "When the Pokémon uses Surf or Dive, it will come back with prey. If the Pokémon has over half of its HP remaining, it will return with a Arrokuda. Otherwise, it will return with a Pikachu. When it takes damage, it will spit out the prey to attack, dealing damage equal to 1/4 of the target's maximum HP. Additonally, Arrokuda will lower the target's Defense by one stage, while Pikachu will induce paralysis in the target."),

        Ability(name: "Guts", detail: "It’s so gutsy that having a status condition boosts the Pokémon’s Attack stat by 50%. If it is burned, Attack is not lowered as it usually is."),

        Ability(name: "Harvest", detail: "If the Pokémon has used a Berry, at the end of each turn, there is a 50% chance it will be restored."),

        Ability(name: "Healer", detail: "At the end of every turn, there is a 30% chance that an adjacent ally's status condition will be cured."),

        Ability(name: "Heatproof", detail: "The heatproof body of the Pokémon halves the damage from Fire-type moves that hit it as well as the damage from burns."),

        Ability(name: "Heavy Metal", detail: "Doubles the Pokémon’s weight."),

        Ability(name: "Honey Gather", detail: "If the Pokémon has no held item, it has a chance to obtain Honey after a battle. The chance starts at 5% for a Pokémon between levels 1 and 10, but rises to a maximum of 50% for a Pokémon between levels 91 and 100."),

        Ability(name: "Huge Power", detail: "Doubles the Pokémon’s Attack stat."),

        Ability(name: "Hunger Switch", detail: "The Pokémon changes its form, alternating between its Full Belly Mode and Hangry Mode after the end of each turn."),

        Ability(name: "Hustle", detail: "Boosts the Attack stat by 50%, but lowers accuracy of physical moves by 20%. Outside of battle, if the Pokémon leads the party, wild Pokémon are 50% more likely to be at a higher level."),

        Ability(name: "Hydration", detail: "Heals status conditions at the end of each turn if it’s raining."),

        Ability(name: "Hyper Cutter", detail: "The Pokémon’s proud of its powerful pincers. They prevent other Pokémon from lowering its Attack stat."),

        Ability(name: "Ice Body", detail: "The Pokémon is immune to hailstorm damage and regains 1/16 of its maximum HP after every turn in a hailstorm."),

        Ability(name: "Ice Face", detail: "The Pokémon’s ice head can take one physical attack without suffering damage, but the attack also changes the Pokémon’s appearance. The ice will be restored when it hails."),

        Ability(name: "Ice Scales", detail: "The Pokémon is protected by ice scales, which halve the damage taken from special moves."),

        Ability(name: "Illuminate", detail: "Outside of battle, if the Pokémon leads the party, raises the likelihood of meeting wild Pokémon by 100% by illuminating the surroundings."),

        Ability(name: "Imposter", detail: "The Pokémon transforms itself into the Pokémon it’s facing."),

        Ability(name: "Infiltrator", detail: "Passes through the opposing Pokémon’s barrier, substitute, and the like and strikes. This includes moves such as Reflect, Light Screen, Safeguard, Mist, and Aurora Veil. Outside of battle, if the Pokémon leads the party, wild Pokémon are less likely to appear."),

        Ability(name: "Innards Out", detail: "Damages the attacker landing the finishing hit by the amount equal to its last HP."),

        Ability(name: "Inner Focus", detail: "The Pokémon’s intensely focused, and that protects the Pokémon from flinching."),

        Ability(name: "Insomnia", detail: "The Pokémon is suffering from insomnia and cannot fall asleep."),

        Ability(name: "Intimidate", detail: "The Pokémon intimidates opposing Pokémon upon entering battle, lowering their Attack stat by one stage. Outside of battle, if the Pokémon leads the party, wild Pokémon are 50% less likely to be at a lower level."),

        Ability(name: "Intrepid Sword", detail: "Boosts the Pokémon’s Attack stat by one stage when the Pokémon enters a battle."),

        Ability(name: "Iron Barbs", detail: "Inflicts damage on the attacker equal to 1/8 of its maximum HP upon contact with iron barbs, that is, when the attacker uses a move that makes contact with the Pokémon."),

        Ability(name: "Iron Fist", detail: "Powers up punching moves by 20%."),

        Ability(name: "Justified", detail: "Being hit by a Dark-type move boosts the Attack stat of the Pokémon by one stage, for justice."),

        Ability(name: "Keen Eye", detail: "Keen eyes prevent other Pokémon from lowering this Pokémon’s accuracy."),

        Ability(name: "Klutz", detail: "The Pokémon can’t use any held items."),

        Ability(name: "Leaf Guard", detail: "Prevents major status conditions in harsh sunlight."),

        Ability(name: "Levitate", detail: "By floating in the air, the Pokémon receives full immunity to all Ground-type moves."),

        Ability(name: "Libero", detail: "Changes the Pokémon’s type to the type of the move it’s about to use."),

        Ability(name: "Light Metal", detail: "Halves the Pokémon’s weight."),

        Ability(name: "Lightning Rod", detail: "The Pokémon draws in all Electric-type moves. Instead of being hit by Electric-type moves, it boosts its Sp. Atk. by one stage."),

        Ability(name: "Limber", detail: "Its limber body protects the Pokémon from paralysis."),

        Ability(name: "Liquid Ooze", detail: "The oozed liquid has a strong stench, which damages attackers using any draining move (such as Leech Life or Giga Drain) instead of healing them."),

        Ability(name: "Liquid Voice", detail: "All sound-based moves become Water-type moves."),

        Ability(name: "Long Reach", detail: "The Pokémon uses its moves without making contact with the target."),

        Ability(name: "Magic Bounce", detail: "Reflects status moves back onto the attacker instead of getting hit by them."),

        Ability(name: "Magician", detail: "The Pokémon steals the held item of a Pokémon it hits with a move."),

        Ability(name: "Magma Armor", detail: "The Pokémon is covered with hot magma, which prevents the Pokémon from becoming frozen. Outside of battle, if the Pokémon is in the party, eggs hatch in half the number of steps as usual."),

        Ability(name: "Magnet Pull", detail: "Prevents Steel-type Pokémon from switching out or fleeing using its magnetic force. Outside of battle, if the Pokémon leads the party, it is 50% more likely that a Pokémon encountered in the wild will be Steel-type."),

        Ability(name: "Marvel Scale", detail: "The Pokémon’s marvelous scales boost the Defense stat by 50% if it has a major status condition."),

        Ability(name: "Mega Launcher", detail: "Powers up aura and pulse moves by 50%. In the case of Heal Pulse, HP restored is also increased by 50%."),

        Ability(name: "Merciless", detail: "The Pokémon’s attacks become critical hits if the target is poisoned."),

        Ability(name: "Mimicry", detail: "Changes the Pokémon’s type depending on the terrain. During Electric Terrain, it will become Electric-type. During Grassy Terrain, it will become Grass-type. During Misty Terrain, it will become Fairy-type. During Psychic Terrain, it will become Psychic-type. If there is no special terrain, the Pokémon will be its usual type."),

        Ability(name: "Minus", detail: "Boosts the Sp. Atk stat of the Pokémon by 50% if an ally with the Plus or Minus Ability is also in battle."),

        Ability(name: "Mirror Armor", detail: "Bounces back only the stat-lowering effects that the Pokémon receives."),

        Ability(name: "Misty Surge", detail: "Turns the ground into Misty Terrain when the Pokémon enters a battle. Under this terrain, Pokémon on the ground are protected from status conditions and the power of Dragon-type moves is halved. The terrain lasts for five turns."),

        Ability(name: "Mold Breaker", detail: "Moves can be used on the Pokémon's target regardless of its Abilities."),

        Ability(name: "Moody", detail: "Raises one random stat by two stages and lowers another random stat by one stage every turn."),

        Ability(name: "Motor Drive", detail: "Boosts its Speed stat by one stage if hit by an Electric-type move instead of taking damage."),

        Ability(name: "Moxie", detail: "The Pokémon shows moxie, and that boosts the Attack stat one stage after knocking out any Pokémon."),

        Ability(name: "Multiscale", detail: "Reduces the amount of damage the Pokémon takes by half while its HP is full, save for moves that deal direct damage."),

        Ability(name: "Multitype", detail: "Changes the Pokémon’s type to match the Plate or Z-Crystal it holds."),

        Ability(name: "Mummy", detail: "Contact with the Pokémon changes the attacker’s Ability to Mummy."),

        Ability(name: "Natural Cure", detail: "All status conditions heal when the Pokémon switches out."),

        Ability(name: "Neuroforce", detail: "Powers up moves that are super-effective by 25%."),

        Ability(name: "Neutralizing Gas", detail: "If the Pokémon with Neutralizing Gas is in the battle, the effects of all Pokémon’s Abilities will be nullified or will not be triggered."),

        Ability(name: "No Guard", detail: "The Pokémon employs no-guard tactics to ensure incoming and outgoing attacks always land. Outside of battle, if the Pokémon leads the party, wild Pokémon are twice as likely to appear."),

        Ability(name: "Normalize", detail: "All the Pokémon’s moves become Normal type. The power of those moves is boosted by 20%."),

        Ability(name: "Oblivious", detail: "The Pokémon is oblivious, and that keeps it from being infatuated or falling for taunts."),

        Ability(name: "Overcoat", detail: "Protects the Pokémon from things like sand, hail, and powder. The Pokémon is immune to damage from weather conditions."),

        Ability(name: "Own Tempo", detail: "This Pokémon has its own tempo, and that prevents it from becoming confused."),

        Ability(name: "Parental Bond", detail: "Parent and child each attacks. In other words, the Pokémon can attack twice. However, the second attack only hits with 25% power."),

        Ability(name: "Pastel Veil", detail: "Protects the Pokémon and its ally Pokémon from being poisoned. Allies are cured of poison when the Pokémon switches in."),

        Ability(name: "Perish Body", detail: "When hit by a move that makes direct contact, the Pokémon and the attacker will faint after three turns unless they switch out of battle."),

        Ability(name: "Pickpocket", detail: "Steals an item from an attacker that made direct contact."),

        Ability(name: "Pickup", detail: "The Pokémon will pick up the item an opposing Pokémon used during a battle if the item is single-use. After winning a battle, all Pokémon with this Ability have a 10% chance to pick up an item."),

        Ability(name: "Pixilate", detail: "Normal-type moves become Fairy-type moves. The power of those moves is boosted by 20%."),

        Ability(name: "Plus", detail: "Boosts the Sp. Atk stat of the Pokémon by 50% if an ally with the Plus or Minus Ability is also in battle."),

        Ability(name: "Poison Heal", detail: "Restores HP if the Pokémon is poisoned instead of losing HP."),

        Ability(name: "Poison Point", detail: "Contact with the Pokémon has a 30% chance to poison the attacker."),

        Ability(name: "Poison Touch", detail: "Has a 30% chance to poison a target when the Pokémon makes contact."),

        Ability(name: "Power Construct", detail: "Other Cells gather to aid when its HP becomes half or less. Then the Pokémon changes its form to Complete Forme."),

        Ability(name: "Power of Alchemy", detail: "The Pokémon copies the Ability of a defeated ally."),

        Ability(name: "Power Spot", detail: "Just being next to the Pokémon powers up moves by 30%."),

        Ability(name: "Prankster", detail: "Gives +1 priority to status moves."),

        Ability(name: "Pressure", detail: "By putting pressure on the opposing Pokémon, it raises their PP usage from 1 to 2 for moves targeted at the Pokémon. Outside of battle, if the Pokémon leads the party, wild Pokémon are 50% more likely to be at a higher level."),

        Ability(name: "Primordial Sea", detail: "The Pokémon changes the weather to heavy rain, nullifing Fire-type attacks completely. The heavy rain will remain as long as the Pokémon is in battle, and cannot be replaced with a regular weather condition."),

        Ability(name: "Prism Armor", detail: "Reduces the power of supereffective attacks taken by 25%."),

        Ability(name: "Propeller Tail", detail: "Ignores the effects of opposing Pokémon’s Abilities and moves that draw in moves."),

        Ability(name: "Protean", detail: "Changes the Pokémon’s type to the type of the move it’s about to use."),

        Ability(name: "Psychic Surge", detail: "Turns the ground into Psychic Terrain when the Pokémon enters a battle. While the terrain is active, Pokémon on the ground cannot be hit by positive-priority moves and the power of Psychic-type moves used by grounded Pokémon is increased by 50%."),

        Ability(name: "Punk Rock", detail: "Boosts the power of sound-based moves by 30%. The Pokémon also takes half the damage from these kinds of moves."),

        Ability(name: "Pure Power", detail: "Using its pure power, the Pokémon doubles its Attack stat."),

        Ability(name: "Queenly Majesty", detail: "Its majesty pressures the opposing Pokémon, making it unable to attack using priority moves."),

        Ability(name: "Quick Draw", detail: "When using a damaging move, the Pokémon has a 30% chance to move first within its priority bracket."),

        Ability(name: "Quick Feet", detail: "Boosts the Speed stat by 50% if the Pokémon has a major status condition. If it is paralyzed, the Pokémon does not suffer a drop in Speed."),

        Ability(name: "Rattled", detail: "Dark-, Ghost-, and Bug-type moves that hit the Pokémon scare it and boost its Speed stat by one stage."),

        Ability(name: "Receiver", detail: "The Pokémon copies the Ability of a defeated ally."),

        Ability(name: "Reckless", detail: "Powers up moves that have recoil damage by 20%."),

        Ability(name: "Refrigerate", detail: "Normal-type moves become Ice-type moves. The power of those moves is boosted by 20%."),

        Ability(name: "Regenerator", detail: "Restores one-third of the Pokémon's maximum HP when withdrawn from battle."),

        Ability(name: "Ripen", detail: "Ripens Berries and doubles their effect."),

        Ability(name: "Rivalry", detail: "Becomes competitive and deals 25% more damage to Pokémon of the same gender, but deals 25% less to Pokémon of the opposite gender."),

        Ability(name: "RKS System", detail: "Changes the Pokémon’s type to match the memory disc it holds."),

        Ability(name: "Rock Head", detail: "Protects the Pokémon from recoil damage."),

        Ability(name: "Rough Skin", detail: "With its rough skin, this Pokémon inflicts damage equal to one-eighth of the attacker's maximum HP to the attacker on contact."),

        Ability(name: "Run Away", detail: "Enables a sure getaway from wild Pokémon."),

        Ability(name: "Sand Force", detail: "Boosts the power of Rock-, Ground-, and Steel-type moves by 30% in a sandstorm. The Pokémon is immune to sandstorm damage."),

        Ability(name: "Sand Rush", detail: "Doubles the Pokémon’s Speed stat in a sandstorm. The Pokémon is immune to sandstorm damage."),

        Ability(name: "Sand Spit", detail: "The Pokémon creates a sandstorm when it’s hit by an attack. The sandstorm lasts for five turns."),

        Ability(name: "Sand Stream", detail: "The Pokémon summons a sandstorm when it enters a battle. The sandstorm lasts for five turns."),

        Ability(name: "Sand Veil", detail: "Boosts the Pokémon’s evasiveness by 20% in a sandstorm. The Pokémon is immune to sandstorm damage."),

        Ability(name: "Sap Sipper", detail: "Boosts the Attack stat by one stage if hit by a Grass-type move instead of taking damage."),

        Ability(name: "Schooling", detail: "When it has more than 25% of its HP and is at least level 20, the Pokémon forms a powerful school. It stops schooling when its HP falls below 25%. This Ability cannot be removed or replaced."),

        Ability(name: "Scrappy", detail: "The Pokémon can hit Ghost-type Pokémon with Normal- and Fighting-type moves."),

        Ability(name: "Screen Cleaner", detail: "When the Pokémon enters a battle, the effects of Light Screen, Reflect, and Aurora Veil are nullified for both opposing and ally Pokémon."),

        Ability(name: "Serene Grace", detail: "Doubles the likelihood of additional effects occurring when attacking."),

        Ability(name: "Shadow Shield", detail: "Reduces the amount of damage the Pokémon takes by half while its HP is full, save for moves that deal direct damage."),

        Ability(name: "Shadow Tag", detail: "This Pokémon steps on the opposing Pokémon’s shadow to prevent it from escaping."),

        Ability(name: "Shed Skin", detail: "At the end of every turn, the Pokémon has a 1/3 chance to heal its own major status conditions by shedding its skin."),

        Ability(name: "Shell Armor", detail: "A hard shell protects the Pokémon from critical hits."),

        Ability(name: "Shield Dust", detail: "This Pokémon’s dust blocks the additional effects of attacks taken."),

        Ability(name: "Shields Down", detail: "When its HP becomes half or less, the Pokémon’s shell breaks and it becomes aggressive, changing into its Meteor Form, in which it cannot be afflicted by status conditions."),

        Ability(name: "Simple", detail: "The stat changes the Pokémon receives are doubled."),

        Ability(name: "Skill Link", detail: "Maximizes the number of times multistrike moves hit."),

        Ability(name: "Slow Start", detail: "For five turns, the Pokémon’s Attack and Speed stats are halved."),

        Ability(name: "Slush Rush", detail: "Doubles the Pokémon’s Speed stat in a hailstorm."),

        Ability(name: "Sniper", detail: "Powers up moves by 1.5x if they become critical hits when attacking."),

        Ability(name: "Snow Cloak", detail: "Boosts evasiveness by 20% in a hailstorm. The Pokémon is immune to damage from a hailstorm."),

        Ability(name: "Snow Warning", detail: "The Pokémon summons a hailstorm when it enters a battle. The storm lasts for five turns."),

        Ability(name: "Solid Rock", detail: "Reduces the power of super-effective attacks taken by 25%."),

        Ability(name: "Soul-Heart", detail: "Boosts its Sp. Atk stat by one stage every time a Pokémon faints."),

        Ability(name: "Soundproof", detail: "Soundproofing gives the Pokémon full immunity to all sound-based moves."),

        Ability(name: "Speed Boost", detail: "Its Speed stat is boosted by one stage at the end of every turn."),

        Ability(name: "Stakeout", detail: "Doubles the damage dealt to the target’s replacement if the target switches out."),

        Ability(name: "Stall", detail: "The Pokémon moves after all other Pokémon do within its priority bracket."),

        Ability(name: "Stalwart", detail: "Ignores the effects of opposing Pokémon’s Abilities and moves that draw in moves."),

        Ability(name: "Stamina", detail: "Boosts the Defense stat by one stage when hit by an attack."),

        Ability(name: "Stance Change", detail: "The Pokémon changes its form to Blade Forme when it uses an attack move and changes to Shield Forme when it uses King’s Shield."),

        Ability(name: "Steadfast", detail: "The Pokémon’s determination boosts the Speed stat by one stage each time the Pokémon flinches."),

        Ability(name: "Steam Engine", detail: "Boosts the Pokémon’s Speed stat by three stages if hit by a Fire- or Water-type move."),

        Ability(name: "Steelworker", detail: "Powers up Steel-type moves by 50%."),

        Ability(name: "Steely Spirit", detail: "Powers up this Pokémon’s and its ally Pokémon’s Steel-type moves by 50%."),

        Ability(name: "Stench", detail: "By releasing stench when attacking, this Pokémon has a 10% chance of causing the target to flinch. Outside of battle, if the Pokémon leads the party, wild Pokémon are half as likely to appear."),

        Ability(name: "Sticky Hold", detail: "Items held by the Pokémon are stuck fast and cannot be removed by other Pokémon. Outside of battle, if the Pokémon leads the party, bites will occur more often when fishing."),

        Ability(name: "Storm Drain", detail: "Draws in all Water-type moves. Instead of being hit by Water-type moves, it boosts its Sp. Atk by one stage."),

        Ability(name: "Strong Jaw", detail: "The Pokémon’s strong jaw boosts the power of its biting moves by 50%."),

        Ability(name: "Sturdy", detail: "It cannot be knocked out with one hit. One-hit KO moves cannot knock it out, either (save for moves inflicted by the Pokémon itself). In either case, the Pokémon will survive with 1 HP remaining."),

        Ability(name: "Suction Cups", detail: "This Pokémon uses suction cups to stay in one spot to negate all moves and items that force switching out. Outside of battle, if the Pokémon leads the party, bites will occur more often when fishing."),

        Ability(name: "Super Luck", detail: "The Pokémon is so lucky that the critical-hit ratios of its moves are boosted by one stage."),

        Ability(name: "Surge Surfer", detail: "Doubles the Pokémon’s Speed stat on Electric Terrain."),

        Ability(name: "Sweet Veil", detail: "Prevents itself and ally Pokémon from falling asleep."),

        Ability(name: "Swift Swim", detail: "Doubles the Pokémon’s Speed stat in rain."),

        Ability(name: "Symbiosis", detail: "The Pokémon passes its item to an ally that has used up an item."),

        Ability(name: "Synchronize", detail: "The attacker will receive the same status condition if it inflicts a burn, poison, or paralysis to the Pokémon. Outside of battle, if the Pokémon leads the party, there is a 50% chance a wild Pokémon will have the same Nature as the Pokémon."),

        Ability(name: "Tangled Feet", detail: "Attacks on the Pokémon have their accuracy halved if the Pokémon is confused."),

        Ability(name: "Tangling Hair", detail: "Contact with the Pokémon lowers the attacker’s Speed stat by one stage."),

        Ability(name: "Technician", detail: "The Pokémon's moves with base power 60 or below have their power boosted by 50%."),

        Ability(name: "Telepathy", detail: "Anticipates an ally’s attack and dodges it."),

        Ability(name: "Teravolt", detail: "Moves can be used on the target regardless of its Abilities."),

        Ability(name: "Thick Fat", detail: "The Pokémon is protected by a layer of thick fat, which halves the damage taken from Fire- and Ice-type moves."),
        
        Ability(name: "Tough Claws", detail: "Powers up moves that make direct contact by 30%."),

        Ability(name: "Toxic Boost", detail: "Powers up physical attacks by 50% when the Pokémon is poisoned."),

        Ability(name: "Trace", detail: "When it enters a battle, the Pokémon copies an opposing Pokémon’s Ability."),

        Ability(name: "Transistor", detail: "Powers up Electric-type moves by 50%."),

        Ability(name: "Triage", detail: "Gives +3 priority to healing moves used by the Pokémon."),

        Ability(name: "Truant", detail: "The Pokémon can’t use a move if it had used a move on the previous turn."),

        Ability(name: "Turboblaze", detail: "Moves can be used on the target regardless of its Abilities."),

        Ability(name: "Unburden", detail: "Doubles the Speed stat if the Pokémon’s held item is used or lost."),

        Ability(name: "Unnerve", detail: "Unnerves opposing Pokémon and makes them unable to eat Berries."),

        Ability(name: "Unseen Fist", detail: "The Pokémon can attack opponents even if they are protected from the move by means such as Protect and Detect."),

        Ability(name: "Victory Star", detail: "Boosts the accuracy of its allies and itself by 10%."),

        Ability(name: "Vital Spirit", detail: "The Pokémon is full of vitality, and that prevents it from falling asleep."),

        Ability(name: "Volt Absorb", detail: "Restores one-fourth of the Pokémon's HP if hit by an Electric-type move instead of taking damage."),

        Ability(name: "Wandering Spirit", detail: "The Pokémon exchanges Abilities with a Pokémon that hits it with a move that makes direct contact."),

        Ability(name: "Water Absorb", detail: "Restores one-fourth of the Pokémon's HP if hit by an Water-type move instead of taking damage."),
        
        Ability(name: "Water Bubble", detail: "Lowers the power of Fire-type moves done to the Pokémon by 50% and prevents the Pokémon from getting a burn. Water-type moves used by the Pokémon hit with double the power."),

        Ability(name: "Water Compaction", detail: "Boosts the Pokémon’s Defense stat by two stages when hit by a Water-type move."),

        Ability(name: "Water Veil", detail: "The Pokémon is covered with a water veil, which prevents the Pokémon from getting a burn."),

        Ability(name: "Weak Armor", detail: "Physical attacks to the Pokémon lower its Defense stat by one stage but raise its Speed stat by two stages."),

        Ability(name: "White Smoke", detail: "The Pokémon is protected by its white smoke, which prevents other Pokémon from lowering its stats."),

        Ability(name: "Wimp Out", detail: "The Pokémon cowardly switches out or flees a wild encounter when its HP becomes half or less."),

        Ability(name: "Wonder Guard", detail: "Its mysterious power only lets supereffective moves hit the Pokémon."),

        Ability(name: "Wonder Skin", detail: "Makes status moves targeted at the Pokémon have half their normal accuracy."),

        Ability(name: "Zen Mode", detail: "Changes the Pokémon’s form to Zen Mode when its HP is half or less.")
    
    ]
    
    // Functions
    static func getDetail(ability: String) -> String {
        for eachAbility in abilityList {
            if eachAbility.name == ability {
                return eachAbility.detail
            }
        }
        return ""
    }
    
}
