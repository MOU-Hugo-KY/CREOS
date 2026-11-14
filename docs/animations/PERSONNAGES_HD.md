# Personnages en 2D illustrée nette

Le mode actif utilise les dessins illustrés HD déjà présents et leurs squelettes 2D, à la
place des petites images pixel des héros. Ce changement réutilise leurs versions dessinées
existantes : ce ne sont pas des agrandissements ni de nouveaux dessins des derniers costumes
pixel. Les silhouettes et les détails correspondent donc aux fiches illustrées du dépôt.

Les 19 héros sont animés par interpolation des articulations, sans limite de 8 ou 16 poses.
Le port utilise les mêmes personnages et leurs marches ; les portraits et les cartes utilisent
les images HD. Les pièces illustrées ont des mipmaps et un filtrage lissé pour garder des
contours propres lorsqu'elles sont réduites à l'écran. Les effets de combat dessinés prennent
le relais des effets pixel, y compris pour les quatuors.

Le commutateur existant est `PixelSheet.enabled` dans `scripts/anim/pixel_sheet.gd`, désormais
à `false` par défaut. À `true`, les atlas pixel et leurs anciens tests restent utilisables.
Le décor, les icônes et les sources de monstres conservent leurs propres styles et résolutions ;
ce changement ne redessine pas les assets dont la source est elle-même en pixel art.

Validation : 19 squelettes, dix clips par héros, pièces et portraits disponibles, filtrage HD,
combat complet et navigation du hub. Le contrôle visuel utilise la vraie fiche de Corbin et la
scène de combat. Les tests pixel activent leur mode explicitement pour vérifier les archives.

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_hd_characters.gd
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/smoke_battle.gd --fixed-fps 60
godot --headless --path . --script res://tests/smoke_hub.gd --fixed-fps 60
```

Vérifié avec Godot 4.6.3 et OpenGL Compatibility. Le projet cible 4.7 ; vérification sur téléphone
encore nécessaire. Les messages de ressources en sortie déjà présents ne sont pas traités ici.
