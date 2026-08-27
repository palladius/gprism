# TODO - GPrism

> 📌 **Backlog & Architetture per GPrism**

---

## ⚡ 1. Performance: Single-Pass Remote Metadata Cache (`gprism check-all` / `gprism cache-sync`)
- [ ] **Problema di Lentezza:** Attualmente `gprism status` e `gprism pull` effettuano singole chiamate sequenziali a GCP Secret Manager / `gcloud secrets` per ciascun file/repo, impiegando tempi biblici per capire se un secret esiste o meno.
- [ ] **Soluzione Bulk Cache:**
  - Implementare un comando `gprism check-all` (o cache sync automatico con TTL) che esegue **un'unica passata bulk** su Secret Manager (`gcloud secrets list --project=... --format=json` o REST API) in 5–10 secondi.
  - Salvare l'indice dei metadati remoti in `~/.config/gprism/remote_secrets_cache.json` (memorizzando *solo l'esistenza*, nomi, label e timestamp, **senza** scaricare i payload dei secret).
  - Tutti i comandi `status` e `check` locali interrogano istantaneamente questa cache a tempo zero.

---

## 🔄 2. Cross-Repo Discovery & Safe Batch Pull (`gprism safe-pull-all` / `gprism pull-all --safe`)
- [ ] **Risoluzione della Frammentazione Multi-Repo:**
  - Poiché i progetti sono frammentati in oltre 100 repository sotto `~/git/*`, l'utente non può ricordarsi di entrare manualmente in ogni cartella per dare `gprism pull`.
- [ ] **Scansione & Diff Globale:**
  - Scansiona tutti i `.git-privatize.list` presenti in `~/git/*` e li confronta con l'indice `remote_secrets_cache.json`.
  - Evidenzia immediatamente:
    - 📥 **Mancanti in locale:** Secret presenti su Secret Manager ma assenti nei repo locali (es. dopo clonazione su nuova macchina).
    - 📤 **Non sincronizzati su remoto:** File locali tracciati in `.git-privatize.list` ma non ancora caricati su GCP.
- [ ] **Safe Pull All (Remote $\to$ Local):**
  - Implementare `gprism safe-pull-all` per scaricare e ripristinare in modo sicuro e idempotente i secret mancanti da remoto a locale attraverso tutti i repository, salvaguardando il lavoro principale.

---

## 🔑 3. Keyring & Altre Feature Esistenti
- [ ] Test Linux Keyring implementation (`secret-tool` from `libsecret-tools`) on a Linux computer to verify if `gprism` correctly saves and reads the passphrase.
- [ ] Support adding folders. (Note: this is HARD as it implies potentially 100s of files. Probably the right thing is NOT to support them and only allow individual files).
