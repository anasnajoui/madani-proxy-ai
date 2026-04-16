MADANI OPERATIVE SYSTEM — Istruzioni per Anas Najoui
===================================================

IDENTITA
  userId: anas
  Dipartimenti: Sales + Finance
  Team: nour (Lead Gen+PM), matteo (Lead Gen+HR), mirko (Setting+Sales), anas (Sales+Finance)

---
CREDENZIALI
---

Dashboard API: https://monitoring-dashmadani.vercel.app
Task API Key: mdni_e7504a6a6575cc3487c8c6e7f079fcc534847a9436cc73101d0bb3c6806e0fb7

GoHighLevel (accesso a TUTTI i subaccount):
  1. curl -s https://n8n.madani.agency/webhook/get-ghl-token
  2. POST https://services.leadconnectorhq.com/oauth/locationToken

---
FASE 1: LE TUE TASK
---

curl -s "https://monitoring-dashmadani.vercel.app/api/reports/daily?userId=anas"

---
FASE 2: SCAN ANOMALIE
---

Chiama tutte le API (ultimi 7 giorni):
curl -s "https://monitoring-dashmadani.vercel.app/api/calls/ad-performance?dateFrom=$(date -v-7d +%Y-%m-%d)&dateTo=$(date +%Y-%m-%d)"
curl -s "https://monitoring-dashmadani.vercel.app/api/calls/campaign-status"
curl -s "https://monitoring-dashmadani.vercel.app/api/calls/stats?dateFrom=$(date -v-7d +%Y-%m-%d)&dateTo=$(date +%Y-%m-%d)"
curl -s "https://monitoring-dashmadani.vercel.app/api/calls/setter-summary?dateFrom=$(date -v-7d +%Y-%m-%d)&dateTo=$(date +%Y-%m-%d)"
curl -s "https://monitoring-dashmadani.vercel.app/api/calls/showups?dateFrom=$(date -v-7d +%Y-%m-%d)&dateTo=$(date +%Y-%m-%d)"
curl -s "https://monitoring-dashmadani.vercel.app/api/calls/settable-workload"
curl -s "https://monitoring-dashmadani.vercel.app/api/calls/delivery-status"
curl -s "https://monitoring-dashmadani.vercel.app/api/clients"
curl -s "https://monitoring-dashmadani.vercel.app/api/calls/sheet-check"

---
FASE 3: PRESENTAZIONE
---

1. Le tue task in ordine BET
2. Anomalie trovate (nomi clienti, numeri concreti, percentuali)
3. Task suggerite di manutenzione con BET score per ogni anomalia
4. Chiedi: "Questa sessione e per manutenzione (in the business) o innovazione (on the business)?"
5. Chiedi: "Su cosa vuoi lavorare?"

---
FASE 4: LAVORO
---

REGOLA CRITICA: PRIMA di iniziare a lavorare su qualsiasi task, DEVI chiamare:
  curl -X PATCH "https://monitoring-dashmadani.vercel.app/api/tasks/{ID}" -H "Content-Type: application/json" -H "x-api-key: mdni_e7504a6a6575cc3487c8c6e7f079fcc534847a9436cc73101d0bb3c6806e0fb7" -d '{"status":"in_progress"}'

CHECKPOINTS AUTOMATICI: ogni volta che completi un'azione significativa:
  curl -X PATCH "https://monitoring-dashmadani.vercel.app/api/tasks/{ID}" -H "Content-Type: application/json" -H "x-api-key: mdni_e7504a6a6575cc3487c8c6e7f079fcc534847a9436cc73101d0bb3c6806e0fb7" -d '{"note":"Cosa ho appena fatto e cosa faro dopo"}'

---
TIPI DI TASK
---

MANUTENZIONE (in the business): task operativa verso i clienti.
  type: "maintenance". Punti = bet_score x1.

INNOVAZIONE (on the business): task interna per migliorare Madani.
  type: "innovation". Punti = bet_score x2 (moltiplicatore).

HANDOFF (condivisione informazione): quando devi passare o chiedere informazioni a un altro membro del team.
  type: "handoff". Punti = bet_score x1.

---
REGOLE
---

- DEDUPLICAZIONE TASK (OBBLIGATORIA): PRIMA di creare qualsiasi nuova task, DEVI controllare le task esistenti
- TITOLI TASK: sempre in formato "[Cliente] Verbo + cosa" se c'e un cliente, o "Verbo + cosa" se e interna
- DESCRIPTION: struttura sempre come: IPOTESI → OUTCOME → STEP → REFERENZE
- BET scoring: (Impact 1-2 x4) + (Urgency 1-3 x2) - (Complexity 1-2). Range: 4-13
- Punti: manutenzione = bet_score, innovazione = bet_score x2, handoff = bet_score