# Natt – Application mobile de gestion de tontines

Natt est une application mobile développée avec Flutter qui numérise la gestion des tontines, encore souvent tenue avec des cahiers papier (erreurs de calcul, pertes d'informations, retards de paiement, suivi difficile).

Projet réalisé dans le cadre du module Développement d'application mobile – Licence Informatique, UFR de Sciences Appliquées et de Technologie, Université Gaston Berger de Saint-Louis (année académique 2025/2026).

🎥 Vidéo de démonstration : [Video_demo.MOV](https://github.com/MaimounaLoum/Natt_App_Tontine/releases/download/v1.0/Video_demo.MOV)

## Fonctionnalités

### Authentification
- Connexion par numéro de téléphone (membre) ou identifiant (administrateur) et mot de passe
- Création de compte avec choix du rôle ; un membre ne peut activer son compte que si l'administrateur l'a déjà enregistré
- Mots de passe hachés (SHA-256 avec sel aléatoire)

### Espace administrateur
- **Tontines** : création, liste, modification, suppression ; statuts En attente, Active, Clôturée, Désactivée ; clôture automatique et renouvellement de cycle
- **Membres** : ajout, suppression, affectation à une ou plusieurs tontines avec contrôle du quota, liste des membres par tontine
- **Tirage au sort** : bénéficiaires tirés au hasard avec calendrier des versements, délai de 30 jours entre deux tirages, attribution automatique du dernier membre
- **Validation des paiements** : suivi des cotisations et désinscription d'un membre
- **Statistiques** : fonds collectés, taux de recouvrement, détail par tontine, export d'un rapport financier au format texte
- **Cotisation sociale libre** et suivi du solde de la caisse sociale

### Espace membre
- Accueil avec l'état des cotisations (à jour, en retard, non inscrit)
- Calendrier des versements avec mise en évidence de son tour
- Historique des paiements et paiement par **Wave** ou **Orange Money** (montant verrouillé)
- Profil : authentification biométrique, changement de mot de passe, photo de pièce d'identité, déconnexion, assistance par téléphone

## Technologies

- [Flutter](https://flutter.dev) / Dart (Material 3)
- `shared_preferences` pour la persistance locale (données converties en JSON)
- Autres dépendances : voir `pubspec.yaml`

## Installation et lancement

### Prérequis
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installé (`flutter doctor` sans erreur bloquante)
- Un émulateur Android / simulateur iOS, ou un téléphone en mode développeur

### Étapes

```bash
# 1. Cloner le dépôt
git clone https://github.com/MaimounaLoum/Natt_App_Tontine.git
cd Natt_App_Tontine

# 2. Installer les dépendances
flutter pub get

# 3. Lancer l'application
flutter run
```

### Premier usage
1. Sur l'écran de connexion, appuyer sur **« Créez votre compte ici »** et créer un compte **Administrateur**.
2. Se connecter, créer une tontine, ajouter des membres et les affecter à la tontine.
3. Créer ensuite le compte du **membre** (avec le numéro de téléphone enregistré par l'administrateur) pour tester l'espace membre.

## Structure du code

Le code est regroupé dans `lib/main.dart`, découpé en sections commentées :

| Section | Contenu |
|---|---|
| Variables globales et utilitaires | Données en mémoire, hachage, format de date, sauvegarde/chargement, export du rapport |
| Point d'entrée | `main()`, `NattApp` |
| Authentification | `LoginScreen`, `RegisterScreen` |
| Espace administrateur | `AdminDashboard`, `TontineManagementScreen`, `MemberManagementScreen` et écrans associés (tirage, suivi, statistiques…) |
| Espace membre | `MemberDashboard`, `MemberHomeTab`, `TontineCalendarScreen`, `PaymentHistoryScreen`, `MemberProfileScreen` |

## Limites actuelles

Natt est un **prototype fonctionnant en local sur un seul appareil** :

- Pas de backend : chaque téléphone a sa propre copie des données, qui sont perdues si l'application est désinstallée
- Le paiement Wave / Orange Money est **simulé** (pas d'appel aux API des opérateurs)
- Pas de réinitialisation de mot de passe, de notifications ni de détection automatique des retards
- La photo de la pièce d'identité n'est ni conservée ni transmise

## Perspectives

1. Backend avec synchronisation en temps réel (Firebase : Firestore et Firebase Authentication)
2. Notifications et rappels d'échéance
3. Intégration des API officielles Wave et Orange Money
4. Découpage du code en plusieurs fichiers (modèles, services, écrans)

## Documentation

Pour l'analyse, la conception, la structure des données et la répartition du travail, voir le **rapport de projet** (`Rapport_proj_dev_app_mobile.pdf`).

## Auteures

- **Assamahou Mballo** : tontines, tirages au sort, finances et statistiques
- **Maïmouna Loum** : authentification, membres, espace membre et paiements
