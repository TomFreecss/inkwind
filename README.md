# Inkwind

*Titolo provvisorio.* Prototipo di un gioco di ruolo originale in cui si
incontrano, si affrontano e si raccolgono creature, con una resa da libro
illustrato ad acquerello: colori chiari, contorni a matita, prati mossi dal
vento e foglie che cadono.

Creature, nomi, mosse e mondo sono inventati per questo progetto. Tutta la
grafica è costruita via codice da forme semplici e shader: non ci sono immagini
o modelli importati.

## Cosa c'è finora

- Un prato esplorabile a caselle, con erba alta, sentieri, alberi, cespugli,
  ceppi, un giardino recintato e un lago dall'acqua in movimento e dalla riva
  sabbiosa.
- Un borgo di fabbricanti d'inchiostro oltre la fila d'alberi a est: mulino a
  vento, bottega dei sigilli, locanda, case, pozzo e orti. Per ora si visita
  soltanto: negli edifici non si entra.
- Il ciclo del giorno: alba, giorno, tramonto e notte, con finestre e lanterne
  che si accendono al buio. Un giorno intero dura dieci minuti.
- Le quattro stagioni, tre giorni ciascuna: alberi in fiore in primavera, verde
  pieno d'estate, foglie rosse e dorate in autunno, neve d'inverno.
- Un compagno che ti segue e incontri casuali nell'erba alta.
- Lotte a turni con cinque elementi che si battono ad anello
  (Brace → Radice → Pietra → Vento → Pioggia → Brace).
- Cattura con i sigilli d'inchiostro e una squadra fino a quattro creature.
- Salvataggio automatico.

È un prototipo: un prato e un borgo, cinque creature, nessuna storia ancora.

## Come si avvia

Serve [Godot 4.7](https://godotengine.org/) o successivo (versione standard,
non .NET). Apri la cartella come progetto e premi F5, oppure da terminale:

```bash
godot --path .
```

## Comandi

| Tasto | Azione |
| --- | --- |
| WASD / frecce | Muovi |
| Shift | Corri |
| Z / Invio / Spazio | Conferma |
| X / Backspace | Indietro |
| Tab / C | Squadra |
| F1 | Attiva o disattiva il filtro pittorico |
| F11 | Schermo intero |
| Esc | Salva ed esci (in lotta: indietro) |
