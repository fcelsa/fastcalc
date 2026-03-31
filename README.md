FastCalc
========

Breve descrizione
- FastCalc è una semplice calcolatrice macOS (menu bar / app) focalizzata su rapidità e cronologia delle operazioni.

Build da sorgente
1. Clona il repo:

   git clone <url>
   cd fastcalc

2. Per eseguire la build e creare il bundle usa lo script incluso:

   ./buildapp.sh

   Lo script esegue la build per arm64 e x86_64 e crea un bundle universale e uno zip nella cartella `dist`.

Note sui test
- Esegui i test con:

   swift test

- Se usi solo Command Line Tools, il progetto usa il package `swift-testing` (aggiunto in `Package.swift`) per la DSL dei test; con Xcode completo puoi rimuovere quella dipendenza.

Risorse
- Metti l'icona dell'app (formato `.icns`) in `resources/`.

Licenza
- (Aggiungi qui la licenza desiderata)
