# Réactions aux événements du combat

Ce document sert à la refonte des héros. Il explique le système et décrit une première proposition pour chacun des 19 héros. Les valeurs sont à régler en jeu.

## Le système (déjà dans le moteur)

### Où sont les données
- Réactions : `data/reactions.json`, une liste par héros. Elles sont rangées avec chaque héros au chargement.
- Moteur : `scripts/combat/battle_engine.gd`, partie « Réactions ».

### Déclencheurs
| Déclencheur | Se produit quand… |
|---|---|
| `ally_crit` | un **autre** allié fait un critique. Compté **une fois par action**, même pour une attaque à plusieurs coups. |
| `ally_crit_count` | l'équipe a fait `count` critiques. Le compteur repart ensuite à zéro. |
| `ultimate_end` | un autre allié termine son ultime. |
| `ally_low_hp` | un allié **passe** sous `threshold` PV. Une seule fois au franchissement, puis de nouveau seulement s'il remonte au-dessus et redescend. |
| `allies_dead` | `count` alliés sont morts. |
| `enemy_killed` | un autre allié tue un ennemi. |
| `mark_applied` | un allié pose une marque. |
| `mark_consumed` | une marque est consommée. |
| `enemy_controlled` | un ennemi est étourdi ou enraciné. |
| `shield_broken` | le bouclier d'un allié se brise sous un coup ennemi. |

### Actions et cibles
| Action | Ce que fait le héros |
|---|---|
| `basic` | `count` attaques de base. |
| `skill` | sa technique à recharge, sans attendre la recharge. |
| `strike` | des effets propres, avec l'animation de l'attaque `anim_slot`. |
| `shield` | un bouclier. |
| `transform` | des bonus permanents et un soin. |

Cibles possibles :
- `event_target` : la cible de l'événement ;
- `random_enemy` : un ennemi au hasard ;
- `other_enemy` : un autre ennemi que celui de l'événement ;
- `attacker` : celui qui a provoqué l'événement ;
- `event_ally` : l'allié touché ;
- `self` : le héros lui-même ;
- `all_allies` : toute l'équipe ;
- `all_enemies` : tous les ennemis.

### Limites
- `per_turn` : remis à zéro à chaque tour normal du héros.
- `per_wave` : remis à zéro à chaque vague.
- `per_combat` : pour tout le combat.

### Ordre de résolution
1. L'action en cours se termine entièrement.
2. Les réactions passent dans une file, dans l'ordre de la formation (de l'avant vers l'arrière), avant la prochaine action normale.
3. Elles ne coûtent pas de tour et ne donnent pas d'énergie.

### Chaînes
- Une réaction peut en déclencher une autre, avec **4 maillons au plus**.
- Un héros ne réagit qu'**une fois par chaîne**. C'est ce qui empêche les boucles.
- La cible est revérifiée juste avant d'agir. Si elle est morte, la réaction en prend une autre quand c'est une attaque, sinon elle s'annule.

### À l'écran
- Chaque réaction joue **après** l'attaque qui l'a provoquée.
- Un éclat part du héros qui réagit, avec un trait de lumière vers sa cible.
- Son nom s'affiche au-dessus de lui, suivi de « ×2 », « ×3 »… quand c'est un maillon de chaîne.
- Le combat attend la fin de la chaîne avant de reprendre.

### Tests (`tests/run_tests.gd`, « Réactions »)
Ils vérifient :
- un critique déclenche deux attaques de réaction ;
- la limite par tour ;
- deux héros qui se répondent ne font pas de boucle ;
- la chaîne critique, puis marque, puis éclair ;
- le seuil de PV, qui ne se déclenche qu'au franchissement ;
- la cible morte remplacée.

## Les quatre profils

- **Déclencheurs** : provoquent souvent des événements (critiques, marques, contrôles, morts).
- **Réacteurs** : répondent à ces événements.
- **Amplificateurs** : rendent les événements plus fréquents ou plus forts.
- **Autonomes** : forts sans réaction, grâce à leurs propres techniques.

## Proposition par héros

**✅ = déjà en jeu** (`data/reactions.json`). Les autres sont des pistes.

| Héros | Profil | Provoque | Réaction | Partenaires possibles | À l'écran |
|---|---|---|---|---|---|
| **Nyx** ✅ | Réacteur | critiques (12 %), vol de vie | Danse du crépuscule : un autre allié critique, 2 attaques de base sur des ennemis au hasard (1 par tour, 3 par vague) | tous les critiques : Rivet, Mei Lian, Tang Su, Corbin ; Nacre si elle donne du critique | elle file d'ennemi en ennemi |
| **Rivet** ✅ | Déclencheur et réacteur | beaucoup de critiques (15 %) | Salve du contrebandier : tous les 3 critiques de l'équipe, tir sur tous les ennemis (2 par vague) | toute équipe à critiques ; ses propres critiques font réagir Nyx | carreaux en éventail |
| **Corbin** ✅ | Déclencheur et réacteur | marques | Charognard : un allié tue, Corbin frappe une autre cible et la **marque** (2 par vague) | ses marques réveillent Orage (éclair) et, une fois consommées, Braise (explosion) | plongée du corbeau |
| **Orage** ✅ | Réacteur | soins | Éclair d'appel : un allié marque un ennemi, éclair dessus (3 par vague). Foudre sur l'entravé : un ennemi est étourdi ou enraciné, éclair (2 par vague) | marques : Corbin, Rivet ; contrôles : Sylve, Jin Seok, Calx, Nacre | éclair qui tombe sur la cible |
| **Braise** ✅ | Réacteur | brûlures | Détonation : une marque est consommée, explosion sur tous les ennemis avec brûlure (2 par vague) | tout ce qui consomme une marque : Corbin, Valen | explosion de flammes |
| **Kharok** ✅ | Réacteur (protection) | provocation | Carapace d'urgence : un allié passe sous 30 % de PV, bouclier aussitôt (3 par combat) | toute équipe | carapace dorée sur l'allié |
| **Bastion** ✅ | Réacteur | provocation, boucliers | Riposte du rempart : le bouclier d'un allié se brise, contre-attaque sur l'agresseur (3 par vague) | ceux qui donnent des boucliers : Kharok, Jin Seok, Sylve | coup de masse sur l'agresseur |
| **Mei Lian** ✅ | Réacteur | critiques (10 %), pétales | Pétales en écho : un allié termine son ultime, Mei Lian lance sa technique sur la même cible (2 par vague) | tous les ultimes, surtout les gros : Aegis, Brume, Calx | pétales qui suivent l'ultime |
| **Valen** ✅ | Autonome, dernier recours | brèche | Dernier debout : trois alliés sont morts, +80 % ATQ, +50 % DEF, +30 % VIT et 40 % de ses PV rendus (1 par combat) | équipes fragiles | il se relève dans la lumière |
| **Tang Su** | Déclencheur | poison, anti-soin, critiques | Piste : un allié critique sur un empoisonné, le poison se propage à un autre ennemi | Rivet, Nyx | aiguilles qui rebondissent |
| **Sylve** | Déclencheur (contrôle) | enracinement | Piste : un allié passe sous 30 %, racines sur son attaquant | Orage (éclair sur l'entravé) | racines qui jaillissent |
| **Jin Seok** | Amplificateur (protection) | déséquilibre, boucliers | Piste : un bouclier allié se brise, cloche d'or sur cet allié | Bastion (riposte) | cloche dorée |
| **Yun Tao** | Réacteur (parade) | parades | Piste : un allié pare une attaque, contre-attaque. Il faut d'abord un événement « parade » dans le moteur. | Jin Seok, Bastion | courant d'eau qui renvoie le coup |
| **Calx** | Déclencheur (contrôle) | retards d'action, étourdissements | Piste : tous les 3 contrôles alliés, glas qui retarde tous les ennemis | Orage, Sylve | cloche qui résonne |
| **Nacre** | Amplificateur | sommeil, bonus de critique | Piste : un allié termine son ultime, +20 % de critique à toute l'équipe pendant 2 tours (fait réagir Nyx et Rivet) | équipes à critiques | poussière de lune |
| **Saffran** | Amplificateur (illusion) | sceaux, leurres | Piste : un ennemi est tué, un leurre sur l'allié le plus blessé | Corbin, Nyx | reflet qui apparaît |
| **Oona** | Autonome (soin) | soins, dissipation | Piste : un allié passe sous 30 %, soin immédiat (pour ne pas doubler Kharok, plutôt soin dans la durée) | toute équipe | jet d'élixir |
| **Brume** | Autonome (préparation) | mouille | Piste : un allié pose une marque, la cible est aussi mouillée | Orage (foudre sur un mouillé) | vague qui recouvre |
| **Aegis** | Autonome (coups lourds) | gros dégâts, ultime puissant | Pas de réaction : il provoque des événements (morts, ultimes) | Mei Lian, Corbin | rien |

## Exemples d'enchaînements possibles aujourd'hui

1. **Rivet, Nyx et Orage** :
   - Rivet fait un critique, Nyx réagit et frappe deux fois ;
   - avec Corbin dans l'équipe, si un coup tue, Corbin marque une autre cible ;
   - Orage la foudroie : 4 maillons.
2. **Corbin et Braise** : Corbin marque, puis une attaque consomme la marque. Braise fait tout exploser.
3. **Kharok et Bastion** :
   - un allié passe sous 30 %, Kharok le protège ;
   - le bouclier finit par se briser, Bastion riposte sur l'agresseur.

## Équilibrage

- Avant les réactions, la ligne des tests affichait : victoires 20/20, durée moyenne 35,8 s.
- Avec les 9 premiers héros réactifs : victoires 20/20, durée moyenne 32,2 s. Les combats vont plus vite.
- Dans le rapport de toute la campagne, monde10_8 au niveau 60 passe de 8/10 à 10/10 victoires. C'est un peu plus facile.

**À surveiller quand on ajoutera les autres héros** : baisser les puissances des réactions ou renforcer les boss.
