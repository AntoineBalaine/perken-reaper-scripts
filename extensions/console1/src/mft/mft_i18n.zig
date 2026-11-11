//! The languages of the windows of the controller: English, in which the texts are written in the code, and French, which this table gives for each of
//! them. The settings choose the language, and the windows read it on every frame, so that a change is seen at once.
//!
//! A text of the code is written `t("…")`, and a text with values `print(buf, "…{s}…", .{…})`. Because the English text is known when the code is
//! compiled, its French text is looked up then, and a text that has none in the table stops the build: no text of the windows can be left in English by
//! mistake. The texts that come from a table of data (the names of the rows of the settings, of the REAPER actions) are translated with `dyn`, which looks
//! them up when they are drawn, and a test checks that every one of them is in the table.
const std = @import("std");

pub const Language = enum {
    en,
    fr,

    /// The name of the language in that language, as the settings show it.
    pub fn label(self: Language) [:0]const u8 {
        return switch (self) {
            .en => "English",
            .fr => "Français",
        };
    }

    pub fn parse(text: []const u8) ?Language {
        return std.meta.stringToEnum(Language, text);
    }
};

/// The language of the windows, which the windows and the handler of the MIDI set from the preferences.
pub var language: Language = .en;

pub fn isFrench() bool {
    return language == .fr;
}

const Entry = struct { en: []const u8, fr: [:0]const u8 };

/// The French of a text of the code, when the code is compiled.
fn french(comptime en: []const u8) [:0]const u8 {
    @setEvalBranchQuota(2_000_000);
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.en, en)) return entry.fr;
    }
    @compileError("the text has no French in mft_i18n.zig: \"" ++ en ++ "\"");
}

/// A text of the windows, in the language of the windows.
pub fn t(comptime en: [:0]const u8) [:0]const u8 {
    const fr = comptime french(en);
    return if (language == .fr) fr else en;
}

/// A text with values, in the language of the windows: the format of the language is used with the values.
pub fn print(buf: []u8, comptime en_fmt: []const u8, args: anytype) ![:0]u8 {
    if (language == .fr) return std.mem.printSentinel(buf, comptime french(en_fmt), args, 0);
    return std.mem.printSentinel(buf, en_fmt, args, 0);
}

/// A text that comes from a table of data, in the language of the windows. A text that the table of the translations does not have is left as it is.
pub fn dyn(en: [:0]const u8) [:0]const u8 {
    if (language != .fr) return en;
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.en, en)) return entry.fr;
    }
    return en;
}

/// Whether the table has the French of a text, which the tests of the tables of data ask.
pub fn has(en: []const u8) bool {
    for (entries) |entry| {
        if (std.mem.eql(u8, entry.en, en)) return true;
    }
    return false;
}

const entries = [_]Entry{
    // ---- the pages, as the windows of the device name them ----
    .{ .en = "INPUT", .fr = "ENTRÉE" },
    .{ .en = "GATE", .fr = "GATE" },
    .{ .en = "EQ", .fr = "EQ" },
    .{ .en = "COMP", .fr = "COMP" },
    .{ .en = "SETTINGS", .fr = "RÉGLAGES" },
    .{ .en = "TRANSPORT", .fr = "TRANSPORT" },
    .{ .en = "AUTO", .fr = "AUTO" },
    .{ .en = "OUTPUT", .fr = "SORTIE" },
    .{ .en = "STRIP", .fr = "STRIP" },
    // ---- the modules ----
    .{ .en = "Input", .fr = "Entrée" },
    .{ .en = "Shape", .fr = "Forme" },
    .{ .en = "Equalizer", .fr = "Égaliseur" },
    .{ .en = "Compressor", .fr = "Compresseur" },
    .{ .en = "Output", .fr = "Sortie" },
    .{ .en = "Comp", .fr = "Comp" },
    .{ .en = "Settings", .fr = "Réglages" },
    .{ .en = "Transport", .fr = "Transport" },
    .{ .en = "Auto", .fr = "Auto" },
    .{ .en = "Channel strip", .fr = "Strip de canal" },
    .{ .en = "FX Selection", .fr = "Sélection d'effets" },
    // ---- the device ----
    .{ .en = "CHAIN", .fr = "CHAÎNE" },
    .{ .en = "HIDE", .fr = "MASQUER" },
    .{ .en = "FXSEL", .fr = "FXSEL" },
    .{ .en = "BYPASS", .fr = "BYPASS" },
    .{ .en = "MUTE", .fr = "MUET" },
    .{ .en = "SOLO", .fr = "SOLO" },
    .{ .en = "PHASE", .fr = "PHASE" },
    .{ .en = "FX SELECTION", .fr = "SÉLECTION D'EFFETS" },
    .{ .en = "Row", .fr = "Ligne" },
    .{ .en = "Flip", .fr = "Basculer" },
    .{ .en = "Save", .fr = "Enregistrer" },
    .{ .en = "Cancel", .fr = "Annuler" },
    .{ .en = "online, mirroring the controller", .fr = "en ligne, reflète le contrôleur" },
    .{ .en = "offline, the controller is not connected", .fr = "hors ligne, le contrôleur n'est pas branché" },
    .{ .en = "Push", .fr = "Bouton" },
    .{ .en = "Dry/Wet", .fr = "Sec/Humide" },
    // ---- the transport page ----
    .{ .en = "Jog", .fr = "Jog" },
    .{ .en = "Item", .fr = "Objet" },
    .{ .en = "Zoom H", .fr = "Zoom H" },
    .{ .en = "Zoom V", .fr = "Zoom V" },
    .{ .en = "Rate", .fr = "Vitesse" },
    .{ .en = "Grid", .fr = "Grille" },
    .{ .en = "Trk", .fr = "Piste" },
    .{ .en = "Mkr", .fr = "Marq." },
    .{ .en = "Play/Stop", .fr = "Lecture/Stop" },
    .{ .en = "Play/Pause", .fr = "Lecture/Pause" },
    .{ .en = "FitH", .fr = "Ajuster H" },
    .{ .en = "FitV", .fr = "Ajuster V" },
    .{ .en = "Rate=1", .fr = "Vitesse=1" },
    .{ .en = "Snap", .fr = "Magnét." },
    .{ .en = "Rec", .fr = "Enreg." },
    .{ .en = "Marker", .fr = "Marqueur" },
    .{ .en = "Loop In", .fr = "Début boucle" },
    .{ .en = "Loop Out", .fr = "Fin boucle" },
    .{ .en = "Order", .fr = "Ordre" },
    .{ .en = "Loop", .fr = "Boucle" },
    .{ .en = "Trk Vol", .fr = "Vol piste" },
    .{ .en = "Trk Pan", .fr = "Pan piste" },
    .{ .en = "No modules", .fr = "Aucun module" },
    // ---- the shapes of the EQ bands ----
    .{ .en = "Low Shelf", .fr = "Plateau bas" },
    .{ .en = "High Shelf", .fr = "Plateau haut" },
    .{ .en = "Band", .fr = "Cloche" },
    .{ .en = "Low Pass", .fr = "Passe-bas" },
    .{ .en = "High Pass", .fr = "Passe-haut" },
    .{ .en = "All Pass", .fr = "Passe-tout" },
    .{ .en = "Notch", .fr = "Coupe-bande" },
    .{ .en = "Band Pass", .fr = "Passe-bande" },
    .{ .en = "Other", .fr = "Autre" },
    // ---- the FX Selection ----
    .{ .en = "FX chains", .fr = "Chaînes d'effets" },
    .{ .en = "Track templates", .fr = "Modèles de piste" },
    .{ .en = "All plugins", .fr = "Tous les plugins" },
    .{ .en = "Categories", .fr = "Catégories" },
    .{ .en = "Developers", .fr = "Développeurs" },
    .{ .en = "Container", .fr = "Conteneur" },
    .{ .en = "Video processor", .fr = "Processeur vidéo" },
    .{ .en = "Recent", .fr = "Récents" },
    .{ .en = "Load FX", .fr = "Charger un effet" },
    .{ .en = "Select preset", .fr = "Choisir un préréglage" },
    .{ .en = "Save preset", .fr = "Enregistrer un préréglage" },
    .{ .en = "Create mapping", .fr = "Créer un mapping" },
    .{ .en = "Presets", .fr = "Préréglages" },
    .{ .en = "Save Preset", .fr = "Enregistrer" },
    .{ .en = "Mapping", .fr = "Mapping" },
    .{ .en = "Single FX", .fr = "FX unique" },
    .{ .en = "Scroll", .fr = "Défiler" },
    .{ .en = "OK", .fr = "OK" },
    .{ .en = "Back", .fr = "Retour" },
    .{ .en = "Type to search", .fr = "Tapez pour chercher" },
    .{ .en = "Default", .fr = "Défaut" },
    .{ .en = "This is the default plugin of the module.", .fr = "C'est le plugin par défaut du module." },
    .{ .en = "Make this plugin the default of the module: a module button inserts it on a track that has none.", .fr = "Faire de ce plugin le défaut du module : le bouton du module l'insère sur une piste qui n'en a pas." },
    .{ .en = "This is the default map of the plugin.", .fr = "C'est la carte par défaut du plugin." },
    .{ .en = "Make this map the default of the plugin: the plugin is loaded with it from now on.", .fr = "Faire de cette carte le défaut du plugin : le plugin est chargé avec elle désormais." },
    .{ .en = "Results", .fr = "Résultats" },
    .{ .en = "No plugin matches.", .fr = "Aucun plugin ne correspond." },
    .{ .en = "Channel strips with a map", .fr = "Strips de canal mappés" },
    .{ .en = "Mapped plugins", .fr = "Plugins mappés" },
    .{ .en = "No plugin has a map for this module.", .fr = "Aucun plugin n'a de carte pour ce module." },
    .{ .en = "Browse", .fr = "Parcourir" },
    .{ .en = "Plugins", .fr = "Plugins" },
    .{ .en = "Nothing in this list.", .fr = "Cette liste est vide." },
    .{ .en = "Maps of {s}", .fr = "Cartes de {s}" },
    .{ .en = "Maps", .fr = "Cartes" },
    .{ .en = "This plugin has no presets saved.", .fr = "Ce plugin n'a aucun préréglage enregistré." },
    .{ .en = "Name of the preset, then Enter", .fr = "Nom du préréglage, puis Entrée" },
    .{ .en = "Presets that exist", .fr = "Préréglages existants" },
    .{ .en = "None yet.", .fr = "Aucun pour l'instant." },
    .{ .en = "FX Selection - Channel strip", .fr = "Sélection d'effets - Strip de canal" },
    .{ .en = "FX Selection - {s}", .fr = "Sélection d'effets - {s}" },
    .{ .en = "The list of plugins could not be read.", .fr = "La liste des plugins n'a pas pu être lue." },
    .{ .en = "Type a name for the preset first.", .fr = "Tapez d'abord un nom pour le préréglage." },
    .{ .en = "A preset has that name: confirm again to replace it.", .fr = "Un préréglage a déjà ce nom : confirmez de nouveau pour le remplacer." },
    .{ .en = "There is no track to load the plugin on.", .fr = "Il n'y a pas de piste où charger le plugin." },
    .{ .en = "The plugin could not be loaded: the track has a channel strip, or REAPER could not add it.", .fr = "Le plugin n'a pas pu être chargé : la piste a un strip de canal, ou REAPER n'a pas pu l'ajouter." },
    .{ .en = "The map could not be chosen.", .fr = "La carte n'a pas pu être choisie." },
    .{ .en = "A map whose name has an equal sign cannot be the default.", .fr = "Une carte dont le nom contient un signe égal ne peut pas être le défaut." },
    .{ .en = "The default map could not be written to default_maps.ini.", .fr = "La carte par défaut n'a pas pu être écrite dans default_maps.ini." },
    .{ .en = "The default could not be changed: out of memory.", .fr = "Le défaut n'a pas pu être changé : mémoire épuisée." },
    .{ .en = "The default is changed for this session, but preferences.ini could not be written.", .fr = "Le défaut est changé pour cette session, mais preferences.ini n'a pas pu être écrit." },
    .{ .en = "This module has no plugin on the track.", .fr = "Ce module n'a pas de plugin sur la piste." },
    .{ .en = "The preset could not be loaded.", .fr = "Le préréglage n'a pas pu être chargé." },
    .{ .en = "There is no track to save the preset from.", .fr = "Il n'y a pas de piste d'où enregistrer le préréglage." },
    .{ .en = "The preset could not be saved ({s}).", .fr = "Le préréglage n'a pas pu être enregistré ({s})." },
    .{ .en = "No default strip set", .fr = "Aucun strip par défaut" },
    .{ .en = "Strip not found", .fr = "Strip introuvable" },
    // ---- the mapping panel ----
    .{ .en = "Alt-click removes this mapping", .fr = "Alt-clic retire cette assignation" },
    .{ .en = "Click to choose this control, then move a parameter in the plugin", .fr = "Cliquez pour choisir ce contrôle, puis bougez un paramètre du plugin" },
    .{ .en = "{s}: {s}\nRight-click to rename the control.", .fr = "{s} : {s}\nClic droit pour renommer le contrôle." },
    .{ .en = "{s}\nRight-click to name the control.", .fr = "{s}\nClic droit pour nommer le contrôle." },
    .{ .en = "Name of the knob {d}", .fr = "Nom du potard {d}" },
    .{ .en = "Name of the push {d}", .fr = "Nom du bouton {d}" },
    .{ .en = "Name", .fr = "Nom" },
    .{ .en = "Name of the control", .fr = "Nom du contrôle" },
    .{ .en = "Clear", .fr = "Effacer" },
    .{ .en = "Map: {s}  v", .fr = "Carte : {s}  v" },
    .{ .en = "Map", .fr = "Carte" },
    .{ .en = "The map of the plugin: choose another, or make a new one from this one.", .fr = "La carte du plugin : choisissez-en une autre, ou créez-en une nouvelle à partir de celle-ci." },
    .{ .en = "New map, made from this one:", .fr = "Nouvelle carte, à partir de celle-ci :" },
    .{ .en = "Create \"{s}\"##createmap", .fr = "Créer « {s} »##createmap" },
    .{ .en = "The map keeps the state of the plugin, which loading the plugin with the map restores. Click to store the state that it has now; Alt-click to keep none.", .fr = "La carte garde l'état du plugin, que le chargement du plugin avec la carte rétablit. Cliquez pour stocker son état actuel ; Alt-clic pour n'en garder aucun." },
    .{ .en = "Store the state of the plugin in the map (its preset and the values of its parameters): loading the plugin with the map restores it.", .fr = "Stocker l'état du plugin dans la carte (son préréglage et les valeurs de ses paramètres) : le chargement du plugin avec la carte le rétablit." },
    .{ .en = "The state could not be removed: {s}.", .fr = "L'état n'a pas pu être retiré : {s}." },
    .{ .en = "The state could not be written: {s}.", .fr = "L'état n'a pas pu être écrit : {s}." },
    .{ .en = "The map could not be chosen: {s}.", .fr = "La carte n'a pas pu être choisie : {s}." },
    .{ .en = "That name is too long for a map.", .fr = "Ce nom est trop long pour une carte." },
    .{ .en = "The name of a map cannot have an equal sign.", .fr = "Le nom d'une carte ne peut pas contenir de signe égal." },
    .{ .en = "The plugin has a map of that name already.", .fr = "Le plugin a déjà une carte de ce nom." },
    .{ .en = "The map could not be made: {s}.", .fr = "La carte n'a pas pu être créée : {s}." },
    .{ .en = "The map file could not be written: {s}.", .fr = "Le fichier de la carte n'a pas pu être écrit : {s}." },
    .{ .en = "no plugin: Load FX  v##plugin{d}", .fr = "aucun plugin : Charger un effet  v##plugin{d}" },
    .{ .en = "no channel strip: Load FX  v##strip", .fr = "aucun strip de canal : Charger un effet  v##strip" },
    .{ .en = "Open FX window", .fr = "Ouvrir la fenêtre du plugin" },
    .{ .en = "REAPER actions", .fr = "Actions REAPER" },
    .{ .en = "Choose in the Action List...", .fr = "Choisir dans la liste d'actions..." },
    .{ .en = "MFT actions", .fr = "Actions MFT" },
    .{ .en = "FX parameters on the track", .fr = "Paramètres d'effets de la piste" },
    .{ .en = "REAPER actions and FX parameters, user page", .fr = "Actions REAPER et paramètres d'effets, page de l'utilisateur" },
    .{ .en = "Assignments", .fr = "Assignations" },
    .{ .en = " (push)", .fr = " (bouton)" },
    .{ .en = "Nothing is assigned yet.", .fr = "Rien n'est encore assigné." },
    .{ .en = "MIDI learn is on: touch an encoder to choose the control, then move a parameter in the plugin window.", .fr = "L'apprentissage MIDI est actif : touchez un encodeur pour choisir le contrôle, puis bougez un paramètre dans la fenêtre du plugin." },
    .{ .en = "MIDI learn is on: touch an encoder to choose the control, then move a parameter in the plugin", .fr = "L'apprentissage MIDI est actif : touchez un encodeur pour choisir le contrôle, puis bougez un paramètre du plugin" },
    .{ .en = "MIDI learn: touch an encoder, then move a parameter in the plugin window", .fr = "Apprentissage MIDI : touchez un encodeur, puis bougez un paramètre dans la fenêtre du plugin" },
    .{ .en = "Back to a plugin for each module", .fr = "Retour à un plugin par module" },
    .{ .en = "Single FX mode: one channel strip for all the modules", .fr = "Mode FX unique : un strip de canal pour tous les modules" },
    .{ .en = "Close the mapping", .fr = "Fermer le mapping" },
    .{ .en = "Action", .fr = "Action" },
    .{ .en = "{s} (missing)", .fr = "{s} (absente)" },
    .{ .en = "Action {d}", .fr = "Action {d}" },
    // ---- the REAPER actions of the AUTO page ----
    .{ .en = "Auto: Trim", .fr = "Auto : Trim" },
    .{ .en = "Auto: Read", .fr = "Auto : Lecture" },
    .{ .en = "Auto: Latch", .fr = "Auto : Latch" },
    .{ .en = "Auto: Preview", .fr = "Auto : Aperçu" },
    .{ .en = "Auto: Write", .fr = "Auto : Écriture" },
    .{ .en = "Toggle metronome", .fr = "Activer le métronome" },
    .{ .en = "Cycle ripple editing", .fr = "Changer le mode d'édition ripple" },
    .{ .en = "Toggle auto-crossfade", .fr = "Activer le fondu enchaîné automatique" },
    .{ .en = "Go to project start", .fr = "Aller au début du projet" },
    .{ .en = "Go to project end", .fr = "Aller à la fin du projet" },
    .{ .en = "Set loop to time selection", .fr = "Boucle sur la sélection temporelle" },
    .{ .en = "Toggle record arm of the selected tracks", .fr = "Armer les pistes sélectionnées" },
    .{ .en = "Undo", .fr = "Annuler" },
    .{ .en = "Redo", .fr = "Rétablir" },
    .{ .en = "Save project", .fr = "Enregistrer le projet" },
    // ---- the settings ----
    .{ .en = "Colors", .fr = "Couleurs" },
    .{ .en = "Knobs", .fr = "Potards" },
    .{ .en = "General", .fr = "Général" },
    .{ .en = "Tracks", .fr = "Pistes" },
    .{ .en = "Default FX", .fr = "Effets par défaut" },
    .{ .en = "Sensitivity", .fr = "Sensibilité" },
    .{ .en = "Fine multiplier", .fr = "Réglage fin" },
    .{ .en = "Show startup message", .fr = "Afficher le message de démarrage" },
    .{ .en = "Show plugin UI", .fr = "Afficher l'interface du plugin" },
    .{ .en = "Language", .fr = "Langue" },
    .{ .en = "Auto insert modules", .fr = "Insérer les modules automatiquement" },
    .{ .en = "Auto insert bypassed", .fr = "Insérer les modules en bypass" },
    .{ .en = "Auto reorder modules", .fr = "Réordonner les modules automatiquement" },
    .{ .en = "Preferred order", .fr = "Ordre préféré" },
    .{ .en = "Default mode", .fr = "Mode par défaut" },
    .{ .en = "Multi FX", .fr = "Multi-FX" },
    .{ .en = "On", .fr = "Oui" },
    .{ .en = "Off", .fr = "Non" },
    .{ .en = "(choose a plugin)", .fr = "(choisir un plugin)" },
    .{ .en = "not done yet", .fr = "pas encore fait" },
    .{ .en = "Double-click to type the value", .fr = "Double-cliquez pour saisir la valeur" },
    .{ .en = "Search\u{2026}", .fr = "Chercher\u{2026}" },
    .{ .en = "Save the settings, and go back to the page", .fr = "Enregistrer les réglages, et revenir à la page" },
    .{ .en = "Cancel: back to the saved values, and to the page", .fr = "Annuler : revenir aux valeurs enregistrées, et à la page" },
    .{ .en = "Install the factory presets (not done yet: the maps are installed by build-install.sh)", .fr = "Installer les préréglages d'usine (pas encore fait : les cartes sont installées par build-install.sh)" },
    .{ .en = "The settings could not be saved to preferences.ini.", .fr = "Les réglages n'ont pas pu être enregistrés dans preferences.ini." },
    .{ .en = "Saved to preferences.ini.", .fr = "Enregistré dans preferences.ini." },
    .{ .en = "Back to the saved values.", .fr = "Retour aux valeurs enregistrées." },
};

test "a text of the code has its French, a text with values its format, and a text of the data is looked up when it is drawn" {
    const tst = std.testing;
    defer language = .en;
    language = .en;
    try tst.expectEqualStrings("Load FX", t("Load FX"));
    language = .fr;
    try tst.expectEqualStrings("Charger un effet", t("Load FX"));
    var buf: [64]u8 = undefined;
    try tst.expectEqualStrings("Cartes de ReaEQ", try print(&buf, "Maps of {s}", .{"ReaEQ"}));
    try tst.expectEqualStrings("Sensibilité", dyn("Sensitivity"));
    try tst.expectEqualStrings("Not in the table", dyn("Not in the table"));
    try tst.expectEqual(@as(?Language, .fr), Language.parse("fr"));
}

test "no text of the table is there twice, so that a text has one French" {
    for (entries, 0..) |a, i| {
        for (entries[i + 1 ..]) |b| try std.testing.expect(!std.mem.eql(u8, a.en, b.en));
    }
}
