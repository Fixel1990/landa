FROM elixir:1.18

# Arbeitsverzeichnis im Container festlegen
WORKDIR /app

# Paketmanager für Elixir installieren
RUN mix local.hex --force && mix local.rebar --force

# Alle Dateien aus dem GitHub-Repo in den Container kopieren
COPY . .

# Abhängigkeiten herunterladen und Projekt kompilieren
RUN mix deps.get
RUN mix compile

# Den Bot starten
CMD ["mix", "run", "--no-halt"]
