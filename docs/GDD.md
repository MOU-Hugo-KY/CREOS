# CREOS — Document de design (GDD)

> Version 0.1 — document vivant, à modifier au fur et à mesure.
> Inspiration : *Dungeon Boss* (Boss Fight Entertainment, 2015). On reprend l'**esprit** et les
> **mécaniques** (équipe de 4 héros, éléments, donjons à vagues + boss, raids PvP), mais **tout le
> contenu est original** : nom, univers, héros, monstres, histoire, graphismes.

---

## 1. Le pitch

**CREOS** est une terre sauvage, jamais cartographiée, où dorment des ressources et des reliques
d'une puissance légendaire. Des chasseurs de tout le continent viennent y faire fortune.

Mais **Morvath, le Mage Noir**, a compris ce que cachent ces reliques : réunies, elles donnent le
contrôle du monde. Il corrompt les terres une à une, réveille les morts et asservit les bêtes géantes.

Le joueur dirige une **Loge de chasseurs**. Son objectif est double :
1. **Devenir la meilleure loge de chasseurs de CREOS** (classement, prestige, richesse).
2. **Empêcher Morvath de corrompre CREOS**, parce qu'une terre corrompue, c'est une terre morte…
   et plus aucune ressource à chasser.

> Le héros n'est pas un saint : c'est un chasseur qui protège **son gagne-pain**. Ce ton
> (un peu mercenaire, un peu héroïque, avec de l'humour) rend l'histoire plus originale qu'un
> « sauvez le monde » classique, et justifie toute la boucle de jeu : chasser → piller → améliorer.

---

## 2. L'univers

### 2.1 Les régions de CREOS (une région = un chapitre de campagne)

| # | Région | Ambiance | Élément dominant | Ennemis | Boss de région |
|---|---|---|---|---|---|
| 0 | **Port-Franc** (hub) | Ville de chasseurs, tavernes, marché | — | — | — |
| 1 | **Forêt de Sylvecroc** | Forêt géante, arbres millénaires | Nature | Animaux géants (loups, sangliers, araignées) | **Grondebête**, ours-titan corrompu |
| 2 | **Marais de Brumenoire** | Brouillard, ruines englouties | Ombre / Eau | Morts-vivants, squelettes | **Vel'Zareth la Liche** (lieutenante de Morvath) |
| 3 | **Côtes de Sel-Brisé** | Falaises, épaves, tempêtes | Eau | Crabes géants, pirates noyés | **Mère-Abysse**, kraken |
| 4 | **Pics de Cendrefer** | Volcans, forges naines abandonnées | Feu | Golems, salamandres | **Ignorak**, golem de lave |
| 5 | **Île des Dragons (Drakonis)** | Île flottante, nids de dragons | Tous | Dragonnets, wyvernes | **Aethryss**, dragonne ancestrale corrompue |
| 6 | **Citadelle de Morvath** | Forteresse noire, fin de l'acte 1 | Ombre | Élite de Morvath | **Morvath, le Mage Noir** |

### 2.2 Les factions

- **La Loge du joueur** : les chasseurs (héros jouables).
- **Le Culte de Morvath** : mages noirs, morts-vivants de la Liche, bêtes corrompues.
- **Les Bêtes de CREOS** : animaux géants **neutres** à l'origine. Morvath les corrompt.
  → Idée de gameplay : une bête vaincue dans sa version corrompue peut être **purifiée** et
  rejoindre la loge comme héros « Bête » (famille à part entière).
- **Les Dragons de Drakonis** : neutres et fiers. Certains sont corrompus et deviennent des boss,
  d'autres deviennent des alliés après une quête.
- **Les Loges rivales** : les autres joueurs (PvP). Elles chassent les mêmes terres que toi.

### 2.3 La Corruption (mécanique centrale de l'histoire)

Chaque région a une **jauge de Corruption** (0 à 100 %).
- Les donjons **corrompus** sont plus durs, mais leur butin est meilleur (fragments de reliques).
- **Purifier** un donjon (le finir avec 3 étoiles) fait baisser la corruption de la région.
- Avec les événements, Morvath « contre-attaque » et la corruption remonte. Ça crée des raisons
  de revenir dans d'anciennes régions.
- Ça remplace l'idée du « mode difficile » par quelque chose qui **raconte l'histoire**.

---

## 3. Les héros

### 3.1 Classes (le rôle au combat)

| Classe | Rôle | Exemple de compétence |
|---|---|---|
| **Gardien** | Tank, attire les coups, protège | Provocation, bouclier d'équipe |
| **Lame** | Gros dégâts sur une cible, rapide | Coup critique, saignement |
| **Arcaniste** | Dégâts magiques de zone | Boule de feu, pluie de glace |
| **Traqueur** | Distance, cible les points faibles | Tir perforant, piège |
| **Mystique** | Soin et soutien | Soin de groupe, purification |

### 3.2 Éléments (le triangle)

```
   Feu ──bat──> Nature ──bat──> Eau ──bat──> Feu
   Lumière <──se battent mutuellement──> Ombre
```

- Avantage : **+30 %** de dégâts. Désavantage : **−25 %** de dégâts.
- Lumière et Ombre se font **+30 %** mutuellement (dangereux dans les deux sens).

### 3.3 Familles (bonus quand plusieurs héros d'une même famille sont dans l'équipe)

- **Chasseurs** (humains de Port-Franc), **Sylvains** (peuple de la forêt), **Nains de Cendrefer**,
  **Sang-Dragon**, **Bêtes purifiées**, **Revenants** (morts-vivants libérés de la Liche).

### 3.4 Rareté (héros, équipement et reliques)

| Rang | Nom | Couleur |
|---|---|---|
| 1 | Commun | Gris |
| 2 | Rare | Bleu |
| 3 | Épique | Violet |
| 4 | Légendaire | Or |
| 5 | Mythique | Rouge |
| 6 | **Relique Ancienne** (rareté max) | Arc-en-ciel / blanc nacré |

> Proposition : « médiéval » décrit l'**ambiance** du jeu et pas une rareté. Le rang max devient
> **Relique Ancienne**, qui colle à l'histoire (les reliques cachées que veut Morvath). On peut
> changer le nom quand vous voulez.

### 3.5 Progression d'un héros

- **Niveau** (XP de chasse), **Étoiles** (1 à 6, avec des fragments du héros),
- **Éveil** (évolution avec des matériaux de chasse : crocs, écailles, essences…),
- **Runes** gravées sur l'équipement (4 emplacements),
- **Relique** : un seul emplacement, objet unique et puissant (rareté Légendaire et au-dessus).

### 3.6 Héros de départ (prototype : modèles KayKit en attendant les nôtres)

| Héros | Classe | Élément | Famille | Modèle du proto |
|---|---|---|---|---|
| **Brannoc le Roc** | Gardien | Nature | Chasseurs | Knight |
| **Kaëla Croc-Vif** | Lame | Feu | Chasseurs | Barbarian |
| **Ysolde des Marées** | Arcaniste | Eau | Sylvains | Mage |
| **Fennir l'Ombre** | Traqueur | Ombre | Chasseurs | Rogue_Hooded |
| **Sœur Aubeline** | Mystique | Lumière | Chasseurs | Rogue |

Les fiches complètes (stats et compétences) sont dans `data/heroes.json`.

---

## 4. Combat (repris de Dungeon Boss, adapté)

- **4 héros contre des vagues de monstres** (2 ou 3 vagues), **puis un boss**.
- **Temps réel avec jauge d'action** : chaque unité a une **Vitesse**. Sa jauge se remplit en continu,
  et quand elle est pleine, l'unité fait son **attaque de base** automatiquement.
- **Compétence spéciale** : chaque héros a une jauge d'**énergie**. Une fois pleine, le joueur
  **touche le portrait** du héros pour lancer sa compétence (ou mode **Auto**).
- **Ciblage** : les Gardiens avec Provocation attirent les attaques. Sinon, la cible est choisie
  selon la compétence (le plus faible, le plus proche, toute l'équipe…).
- **Traits défensifs** : *Cuirasse* (réduit les dégâts physiques), *Garde-mystique* (réduit les
  dégâts magiques).
- Le moteur de combat est **logique pure** (`scripts/combat/`), **déterministe** avec une graine
  aléatoire. Il est testable sans affichage, et l'affichage 3D (`scripts/battle/`) ne fait que
  **lire les événements** du moteur.

---

## 5. Modes de jeu

| Mode | Inspiré de | Description |
|---|---|---|
| **Campagne / Chasses** | Campagne | Régions → donjons → étoiles |
| **Donjons corrompus** | Mode difficile | Version corrompue d'un donjon, meilleur butin |
| **Tour de Morvath** | Tower of Pwnage | Étages infinis de plus en plus durs, classement |
| **Raids de loges** (PvP) | Raids | Attaquer la **base de chasse** d'une loge rivale pour lui voler de l'or. Tu choisis ton équipe de défense. |
| **Chasses de Bêtes Légendaires** | Boss Mode / guildes | Boss géant partagé par toute la guilde, avec des dégâts cumulés |
| **Événements de Corruption** | Événements | Morvath attaque une région, à repousser à temps limité |

---

## 6. Économie (sans pay-to-win !)

Dungeon Boss a perdu ses joueurs quand **les meilleurs héros sont passés derrière un mur payant**.
Règles pour CREOS :
- **Tous les héros sont obtenables en jouant** (fragments sur des donjons précis).
- Monnaies : **Or** (tout), **Gemmes** (premium, aussi gagnables en jeu), **Essences** (par élément),
  **Fragments de Relique**.
- Si un jour il y a de la monétisation : cosmétiques, passe saisonnier, confort. **Jamais de la
  puissance pure à vendre.**

---

## 7. Direction artistique

- **Low-poly stylisé « chibi »** (têtes un peu grosses, couleurs vives), proche de Dungeon Boss.
- Prototype : packs **KayKit (CC0)** déjà dans `assets/kaykit/`.
- Ensuite : nos propres héros, à partir de dessins ou de descriptions → image IA → modèle 3D
  (Higgsfield `generate_3d`, Hunyuan3D, ou modélisation dans Blender via mcp-for-blender).
- Animations : les modèles KayKit contiennent déjà 76 animations (attaque, sort, coup reçu, mort…).

---

## 8. Plateformes et technique

- **Moteur** : Godot 4.7 (GDScript), rendu « Mobile ».
- **Cibles** : Android et iOS en priorité, PC pour le développement.
- **Format** : paysage (1920×1080), comme Dungeon Boss.
- **En ligne (plus tard)** : Nakama (open source) pour les comptes, les raids PvP, les guildes et
  les classements.

---

## 9. Feuille de route

Voir [`ROADMAP.md`](ROADMAP.md).
