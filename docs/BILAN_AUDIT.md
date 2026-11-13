# Bilan de l'audit — 10 novembre 2026

4 agents ont tout lu (sans rien modifier) : combat, économie, technique, idées d'ajouts.
Les chiffres sont des estimations : pas tous simulés.

## 🔴 À corriger d'abord

1. **Sauvegarde perdue si le jeu est coupé pendant l'enregistrement** (`scripts/core/player_data.gd:100`).
   Fichier à moitié écrit → au lancement suivant le jeu repart de zéro. Fix : écrire dans un fichier
   temporaire puis renommer, garder une copie `.bak`, ne jamais réinitialiser sur une lecture ratée.
2. **APK de 720 Mo** : toutes les images sont en PNG brut (`compress/mode=0`) et tout `assets/` part dans
   l'APK. Fix : compression VRAM/WebP pour les fonds et illustrations, pixel art en sans perte, taille max
   2048 px, n'exporter que l'utile. Objectif < 200 Mo.
3. **Collection quasi impossible** : 6 légendaires à 1 % (garantie à 50 tirages), ~0,6 invocation par jour
   → ~1,5 à 2 ans pour tout avoir. Contraire au « pas de pay-to-win » dans les faits.
   Fix : 4-5 %, garantie à 30, éclats de héros + boutique d'éclats pour choisir. Cible ≈ 4 mois.
4. **Murs dans la campagne** : boss du monde 4 injouable avant le niveau 20, monde 6 plus facile que le
   boss du monde 5, saut brutal au monde 7, monde 10 gagnable seulement au niveau 60 (le maximum).
   Fix : difficulté qui monte en continu (~+8 % par niveau d'un monde), ajuster 06_1-4, 07_1, 10_8.

## 🟠 Ensuite

- **Fragments de relique utilisés deux fois** (Lanterne et Druide) : on doit choisir entre invoquer et
  éveiller. Donner une monnaie à part au Druide.
- **Niveau max incohérent** : 150 dans les données, 60 dans le GDD. Choisir 60.
- **Pas assez d'XP** : la campagne donne ~⅓ de l'XP d'un seul héros niveau 60. Croissance 1,08 → 1,06
  ou donjon d'XP du jour.
- **Matériaux inutiles** (`gel_marin`, `bois_epave`, `os_ancien`…) : ils tombent mais ne servent à rien.
- **Trop d'or en fin de jeu**, rien à acheter. **Énergie perdue la nuit** (plein en 8 h) → plafond 100.
- **Sauvegardes anciennes** : pas de migration par version, fusion qui écrase les sous-parties.
- **Fuites mémoire** signalées par les tests (78 objets dans le combat).
- **Héros** : 2 ultimes sans effet direct (bouclier seul, état seul) à renforcer ; vérifier les ultimes
  à 6-8 coups (total ≤ ×2,5) ; Feu à 3 trop rentable (+20 % → +15 %).

## 🟡 Plus tard

- Performance : les personnages se redessinent à chaque image même immobiles (`clip_player.gd:170`).
- Triche possible en changeant l'heure du téléphone (à régler avec le jeu en ligne).
- Code mort : pièces « sobres » de FinPack, prototype de défense.
- Mieux mesurer l'équilibrage : `balance_report.gd` tous les 5 niveaux, sur les 8 niveaux de chaque monde.

## ✨ Idées d'ajouts

**Vite (petit effort)** : pastilles rouges sur les bâtiments quand il y a quelque chose à faire ; or et
gemmes qui volent vers le haut, vibration, ralenti sur le coup fatal du boss ; coffre de connexion sur
7 jours ; bouton « Rejouer » et passes rapides sur les niveaux à 3 étoiles ; album des 152 monstres.

**Ensuite** : donjons du jour (un élément par jour, matériaux précis) ; défis d'équipe (« que du feu »,
« 4 héros max ») ; hauts faits et titres ; événement de saison de 2 semaines ; régions corrompues.

**Plus tard (en ligne)** : Tour de Morvath avec classement ; raids sur les loges des autres joueurs ;
confréries contre une bête légendaire ; prêt de héros entre amis ; ascension des héros.

**Confort** : équipe auto, notification d'énergie pleine, vitesse ×2 retenue, Force avant/après une
amélioration.
