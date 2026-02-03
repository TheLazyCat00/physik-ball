using PackageCompiler

# Erstellt eine Standalone-App im Ordner "build"
# Das Resultat enthält eine ausführbare Datei und alle notwendigen Bibliotheken.
create_app(".", "build";
    executables = ["physik_ball" => "julia_main"], # Name der Exe => Einstiegsfunktion (muss in main.jl definiert sein)
    force = true,
    incremental = false, # True für schnelleren Build, False für kleinere/sauberere Builds
    filter_stdlibs = true
)
