# Démarrer CREOS sur ton PC (≈ 15 minutes)

## 1. Récupérer le projet
Dans un terminal (PowerShell sous Windows), dans le dossier où tu veux le projet :

```bash
git clone https://github.com/MOU-Hugo-KY/CREOS
cd CREOS
```

## 2. Tout installer (une seule commande)
**Windows** (PowerShell, dans le dossier CREOS) :
```powershell
powershell -ExecutionPolicy Bypass -File tools\setup-windows.ps1
```
**Mac / Linux** :
```bash
bash tools/setup-mac-linux.sh
```
Le script installe Git, Node.js, uv, Blender, **Godot 4.7.2** et **Claude Code**. Il branche aussi
les outils de Claude (**MCP Godot** et **MCP Blender**), importe les modèles 3D et lance les tests.

> Pour que Claude pilote Blender, **ouvre Blender** avant de lui demander des modèles 3D.

## 3. Voir le prototype
Ouvre Godot → *Import* → choisis `CREOS/project.godot` → **F5**.
Tu verras 4 chasseurs contre les squelettes de Brumenoire, puis la Liche. Clique sur un portrait
quand l'énergie est à 100 % pour lancer sa compétence.

## 4. Premier message à coller dans Claude Code
Dans le dossier CREOS, tape `claude`, puis colle :

```
Salut ! On reprend CREOS. Lis CLAUDE.md, docs/GDD.md et docs/ROADMAP.md.
Vérifie que les tests passent et que le MCP godot fonctionne (lance le jeu et lis la sortie).
Ensuite attaque l'Étape 1 de la ROADMAP dans l'ordre : fais une tâche à la fois, lance les
tests, fais une capture du jeu pour vérifier le rendu, commit, puis passe à la suivante.
Explique-moi en français simple ce que tu as fait à chaque étape.
```
